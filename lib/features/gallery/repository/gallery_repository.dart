import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Fetches the bytes behind [url]; throws when the download fails.
typedef GalleryDownloader = Future<Uint8List> Function(String url);

/// Manages the gallery's local cache: metadata and thumbnails in Hive, full-resolution originals as plain files
/// under `<base>/gallery/<tripId>/<imageId>.jpg`.
///
/// Originals live on disk rather than in Hive because opening a Hive box loads every value into memory, which for
/// a trip's worth of full-size photos is far too much RAM.
class GalleryRepository {
  final HiveInterface _hive;
  final Future<Directory> Function() _baseDirectory;
  final GalleryDownloader _download;
  final Logger _logger = createLogger('GalleryRepo');

  /// Active trip scope. Everything is namespaced per trip so one trip's cached photos never bleed into another.
  /// `null` means no trip is active yet, in which case reads return empty and writes are no-ops.
  String? _tripId;

  /// Per-trip legacy migrations, memoised so each runs at most once per repository instance.
  final Map<String, Future<void>> _legacyMigrations = {};

  /// In-flight downloads keyed by `<tripId>/<imageId>`, so concurrent requests share one download.
  final Map<String, Future<File>> _inFlightDownloads = {};

  GalleryRepository({
    HiveInterface? hiveInterface,
    Future<Directory> Function()? baseDirectory,
    GalleryDownloader? download,
  }) : _hive = hiveInterface ?? Hive,
       _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _download = download ?? _httpDownload;

  static const metadataBoxPrefix = 'gallery-meta';
  static const savedToPhotosBoxPrefix = 'gallery-saved';

  /// Pre-file-cache installs stored originals as bytes in this Hive box; only read to migrate them to files.
  static const legacyHighResBoxPrefix = 'gallery-res';

  /// Sets the active trip scope. Pass `null` to clear it (no trip active).
  void setTrip(String? tripId) => _tripId = tripId;

  /// Loads the active trip's cached metadata keyed by image id; empty when no trip is active.
  Future<Map<String, ImageModel>> loadImgFromCache() async {
    final tripId = _tripId;
    if (tripId == null) return {};

    final box = await _hive.openBox(_metadataBoxName(tripId));
    return {
      for (final key in box.keys)
        if (key is String && box.get(key) is ImageModel) key: box.get(key) as ImageModel,
    };
  }

  /// Caches `ImageModel` metadata and thumbnail bytes to Hive.
  Future<void> cacheMetadata(ImageModel imageModel) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final box = await _hive.openBox(_metadataBoxName(tripId));
    await box.put(imageModel.id, imageModel);
  }

  /// Returns the cached full-resolution file for [id], or `null` if it isn't cached (or no trip is active).
  Future<File?> fullResFile(String id) async {
    final tripId = _tripId;
    if (tripId == null) return null;
    return _existingFullResFile(tripId, id);
  }

  /// Copies [source] into the full-resolution cache and returns the cached file.
  /// The source is copied rather than referenced because picker temp files can disappear.
  Future<File?> cacheFullRes(String id, File source) async {
    final tripId = _tripId;
    if (tripId == null) return null;
    await _migrateLegacyBox(tripId);
    final target = await _fullResFileFor(tripId, id);
    await _writeAtomically(target, (temp) => source.copy(temp.path));
    _logger.d('Cached full-resolution image $id');
    return target;
  }

  /// Returns the cached full-resolution file for [id], downloading it from [url] first if needed.
  /// Concurrent calls for the same image share one download; download errors are rethrown.
  Future<File?> fetchAndCacheFullRes(String id, String url) async {
    final tripId = _tripId;
    if (tripId == null) return null;

    final cached = await _existingFullResFile(tripId, id);
    if (cached != null) return cached;

    final key = '$tripId/$id';
    return _inFlightDownloads.putIfAbsent(
      key,
      // Block body on purpose: returning the removed future from whenComplete would make it await itself.
      () => _downloadToCache(tripId, id, url).whenComplete(() {
        _inFlightDownloads.remove(key);
      }),
    );
  }

  /// Returns the ids of the active trip's photos this device has already saved to the Photos app.
  Future<Set<String>> loadSavedPhotoIds() async {
    final tripId = _tripId;
    if (tripId == null) return {};
    final box = await _hive.openBox(_savedToPhotosBoxName(tripId));
    return box.keys.whereType<String>().toSet();
  }

  /// Records that the photo [id] of the active trip has been saved to the Photos app on this device.
  Future<void> markPhotoSaved(String id) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final box = await _hive.openBox(_savedToPhotosBoxName(tripId));
    await box.put(id, true);
  }

  /// Deletes everything cached for the active trip: metadata, full-resolution files and saved-to-Photos ids.
  Future<void> reset() async {
    final tripId = _tripId;
    if (tripId == null) return;

    await (await _hive.openBox(_metadataBoxName(tripId))).deleteFromDisk();
    await (await _hive.openBox(_savedToPhotosBoxName(tripId))).deleteFromDisk();
    // Covers a legacy box that was never migrated because full-res files were never accessed.
    if (await _hive.boxExists(_legacyHighResBoxName(tripId))) {
      await (await _hive.openLazyBox(_legacyHighResBoxName(tripId))).deleteFromDisk();
    }

    final directory = await _tripDirectory(tripId);
    if (await directory.exists()) await directory.delete(recursive: true);
    _logger.d('Deleted gallery cache for trip $tripId');
  }

  String _metadataBoxName(String tripId) => '$metadataBoxPrefix-$tripId';
  String _savedToPhotosBoxName(String tripId) => '$savedToPhotosBoxPrefix-$tripId';
  String _legacyHighResBoxName(String tripId) => '$legacyHighResBoxPrefix-$tripId';

  Future<Directory> _tripDirectory(String tripId) async =>
      Directory('${(await _baseDirectory()).path}/gallery/$tripId');

  Future<File> _fullResFileFor(String tripId, String id) async =>
      File('${(await _tripDirectory(tripId)).path}/$id.jpg');

  Future<File?> _existingFullResFile(String tripId, String id) async {
    await _migrateLegacyBox(tripId);
    final file = await _fullResFileFor(tripId, id);
    return await file.exists() ? file : null;
  }

  Future<File> _downloadToCache(String tripId, String id, String url) async {
    final target = await _fullResFileFor(tripId, id);
    final bytes = await _download(url);
    await _writeAtomically(target, (temp) => temp.writeAsBytes(bytes, flush: true));
    _logger.d('Downloaded full-resolution image $id');
    return target;
  }

  /// Writes via a temp file and a rename so a half-written file is never served as the cached original.
  Future<void> _writeAtomically(File target, Future<void> Function(File temp) write) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.part');
    try {
      await write(temp);
      await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  Future<void> _migrateLegacyBox(String tripId) =>
      _legacyMigrations.putIfAbsent(tripId, () => _runLegacyMigration(tripId));

  /// Moves originals from the legacy Hive box into files. Photos whose upload failed exist only there, so they are
  /// migrated rather than dropped. A lazy box keeps all the photos from being loaded into memory at once.
  Future<void> _runLegacyMigration(String tripId) async {
    final boxName = _legacyHighResBoxName(tripId);
    try {
      if (!await _hive.boxExists(boxName)) return;
      final box = await _hive.openLazyBox(boxName);
      for (final key in box.keys.whereType<String>()) {
        final target = await _fullResFileFor(tripId, key);
        if (await target.exists()) continue;
        final bytes = await box.get(key);
        if (bytes is List<int>) await _writeAtomically(target, (temp) => temp.writeAsBytes(bytes, flush: true));
      }
      await box.deleteFromDisk();
      _logger.i('Migrated legacy full-resolution cache for trip $tripId');
    } catch (error, stackTrace) {
      _logger.e('Legacy full-resolution migration failed for trip $tripId', error: error, stackTrace: stackTrace);
    }
  }

  static Future<Uint8List> _httpDownload(String url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status ${response.statusCode}', uri: Uri.parse(url));
      }
      return await consolidateHttpClientResponseBytes(response);
    } finally {
      client.close();
    }
  }
}
