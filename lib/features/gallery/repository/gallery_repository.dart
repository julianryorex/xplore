import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// An HTTP response body to stream into the cache, with its declared length when the server sent one.
class GalleryDownloadResponse {
  final int? contentLength;
  final Stream<List<int>> bytes;

  const GalleryDownloadResponse({required this.contentLength, required this.bytes});
}

/// Starts a GET of [url] and returns its body; throws when the request fails or the status isn't 200.
typedef GalleryDownloader = Future<GalleryDownloadResponse> Function(Uri url);

/// Manages the gallery's local cache: metadata and thumbnails in Hive, full-resolution originals as plain files
/// named `gallery/<tripId>/<imageId>.jpg`.
///
/// Originals live on disk rather than in Hive because opening a Hive box loads every value into memory, which for
/// a trip's worth of full-size photos is far too much RAM. They live in one of two places:
/// - originals added on this device go to a durable directory (Application Support), because until their upload
///   succeeds they are the only copy of the photo;
/// - originals downloaded from the cloud go to the caches directory, which iOS may purge and does not back up,
///   because they can always be fetched again.
class GalleryRepository {
  final HiveInterface _hive;
  final Future<Directory> Function() _durableDirectory;
  final Future<Directory> Function() _cacheDirectory;
  final GalleryDownloader _download;
  final Duration _responseTimeout;
  final Duration _idleTimeout;
  final Duration _downloadTimeout;
  final int _maxDownloadBytes;
  final Logger _logger = createLogger('GalleryRepo');

  /// Per-trip one-off preparation (stale temp file cleanup, legacy migration), memoised per repository instance.
  final Map<String, Future<void>> _tripPreparations = {};

  /// In-flight downloads keyed by `<tripId>/<imageId>`, so concurrent requests share one download.
  final Map<String, Future<File>> _inFlightDownloads = {};

  /// Operations currently using each Hive box, so [closeTrip] never closes a box out from under one.
  final Map<String, int> _boxUsers = {};
  final Map<String, Future<void>> _closingBoxes = {};

  GalleryRepository({
    HiveInterface? hiveInterface,
    Future<Directory> Function()? durableDirectory,
    Future<Directory> Function()? cacheDirectory,
    GalleryDownloader? download,
    this._responseTimeout = const Duration(seconds: 30),
    this._idleTimeout = const Duration(seconds: 30),
    this._downloadTimeout = const Duration(minutes: 3),
    this._maxDownloadBytes = 100 * 1024 * 1024,
  }) : _hive = hiveInterface ?? Hive,
       _durableDirectory = durableDirectory ?? getApplicationSupportDirectory,
       _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _download = download ?? _httpDownload;

  static const metadataBoxPrefix = 'gallery-meta';
  static const savedToPhotosBoxPrefix = 'gallery-saved';

  /// Pre-file-cache installs stored originals as bytes in this Hive box; only read to migrate them to files.
  static const legacyHighResBoxPrefix = 'gallery-res';

  static const _connectionTimeout = Duration(seconds: 15);

  /// Loads [tripId]'s cached metadata keyed by image id.
  Future<Map<String, ImageModel>> loadImgFromCache(String tripId) {
    return _useBox(_metadataBoxName(tripId), (box) async {
      return {
        for (final key in box.keys)
          if (key is String && box.get(key) is ImageModel) key: box.get(key) as ImageModel,
      };
    });
  }

  /// Caches `ImageModel` metadata and thumbnail bytes to Hive.
  Future<void> cacheMetadata(String tripId, ImageModel imageModel) {
    return _useBox(_metadataBoxName(tripId), (box) => box.put(imageModel.id, imageModel));
  }

  /// Returns the cached full-resolution file for [id], or `null` if it isn't cached.
  Future<File?> fullResFile(String tripId, String id) {
    return _existingFullResFile(tripId, id);
  }

  /// Copies [source] into durable storage and returns the copy; it is the photo's only copy until its upload succeeds.
  /// The source is copied rather than referenced because picker temp files can disappear.
  Future<File> cacheFullRes(String tripId, String id, File source) async {
    await _prepareTrip(tripId);
    final target = await _durableFile(tripId, id);
    await _writeAtomically(target, (temp) => source.copy(temp.path));
    _logger.d('Cached full-resolution image $id');
    return target;
  }

  /// Moves [id]'s original from durable storage to the purgeable cache once its upload has succeeded, since the
  /// cloud copy can then replace it. Does nothing if there is no durable copy.
  Future<void> releaseUploadedOriginal(String tripId, String id) async {
    await _prepareTrip(tripId);
    final durable = await _durableFile(tripId, id);
    if (!await durable.exists()) return;
    final cached = await _cacheFile(tripId, id);
    await cached.parent.create(recursive: true);
    try {
      await durable.rename(cached.path);
    } on FileSystemException {
      // The two directories may be on different volumes, where rename can't move files.
      await _writeAtomically(cached, (temp) => durable.copy(temp.path));
      await durable.delete();
    }
  }

  /// Returns the cached full-resolution file for [id], downloading it from the https [url] into the purgeable cache
  /// first if needed. Concurrent calls for the same image share one download; download errors are rethrown.
  Future<File> fetchAndCacheFullRes(String tripId, String id, String url) async {
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

  /// Returns the ids of [tripId]'s photos this device has already saved to the Photos app.
  Future<Set<String>> loadSavedPhotoIds(String tripId) {
    return _useBox(_savedToPhotosBoxName(tripId), (box) async => box.keys.whereType<String>().toSet());
  }

  /// Records that the photo [id] of [tripId] has been saved to the Photos app on this device.
  Future<void> markPhotoSaved(String tripId, String id) {
    return _useBox(_savedToPhotosBoxName(tripId), (box) => box.put(id, true));
  }

  /// Forgets which of [tripId]'s photos were saved to the Photos app, so they can all be saved again.
  Future<void> clearSavedPhotoIds(String tripId) {
    return _useBox(_savedToPhotosBoxName(tripId), (box) => box.clear());
  }

  /// Removes everything this device holds for photo [id] of [tripId]: its
  /// metadata, its saved-to-Photos mark and its full-resolution files.
  Future<void> deletePhoto(String tripId, String id) async {
    await _useBox(_metadataBoxName(tripId), (box) => box.delete(id));
    await _useBox(_savedToPhotosBoxName(tripId), (box) => box.delete(id));
    for (final file in [await _durableFile(tripId, id), await _cacheFile(tripId, id)]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Releases the memory held by [tripId]'s Hive boxes; call it when the user leaves the trip.
  /// Boxes still in use are left open, and any later call for the trip simply reopens them.
  Future<void> closeTrip(String tripId) async {
    for (final name in [_metadataBoxName(tripId), _savedToPhotosBoxName(tripId)]) {
      if ((_boxUsers[name] ?? 0) > 0 || !_hive.isBoxOpen(name)) continue;
      final closing = _hive.box<dynamic>(name).close();
      _closingBoxes[name] = closing;
      await closing;
      if (identical(_closingBoxes[name], closing)) _closingBoxes.remove(name);
    }
  }

  /// Deletes everything cached for [tripId]: metadata, full-resolution files and saved-to-Photos ids.
  Future<void> reset(String tripId) async {
    await _useBox(_metadataBoxName(tripId), (box) => box.deleteFromDisk());
    await _useBox(_savedToPhotosBoxName(tripId), (box) => box.deleteFromDisk());
    // Covers a legacy box that was never migrated because full-res files were never accessed.
    if (await _hive.boxExists(_legacyHighResBoxName(tripId))) {
      await (await _hive.openLazyBox(_legacyHighResBoxName(tripId))).deleteFromDisk();
    }

    for (final directory in await _tripDirectories(tripId)) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    _logger.d('Deleted gallery cache for trip $tripId');
  }

  String _metadataBoxName(String tripId) => '$metadataBoxPrefix-$tripId';
  String _savedToPhotosBoxName(String tripId) => '$savedToPhotosBoxPrefix-$tripId';
  String _legacyHighResBoxName(String tripId) => '$legacyHighResBoxPrefix-$tripId';

  /// Runs [action] on the box [name], keeping [closeTrip] from closing it meanwhile.
  Future<T> _useBox<T>(String name, Future<T> Function(Box<dynamic> box) action) async {
    _boxUsers[name] = (_boxUsers[name] ?? 0) + 1;
    try {
      // Hive keeps returning a closing box from openBox until its close finishes.
      await _closingBoxes[name];
      return await action(await _hive.openBox(name));
    } finally {
      final remaining = _boxUsers[name]! - 1;
      if (remaining == 0) {
        _boxUsers.remove(name);
      } else {
        _boxUsers[name] = remaining;
      }
    }
  }

  Future<Directory> _tripDirectoryIn(Future<Directory> Function() base, String tripId) async =>
      Directory('${(await base()).path}/gallery/$tripId');

  Future<List<Directory>> _tripDirectories(String tripId) async => [
    await _tripDirectoryIn(_durableDirectory, tripId),
    await _tripDirectoryIn(_cacheDirectory, tripId),
  ];

  Future<File> _durableFile(String tripId, String id) async =>
      File('${(await _tripDirectoryIn(_durableDirectory, tripId)).path}/$id.jpg');

  Future<File> _cacheFile(String tripId, String id) async =>
      File('${(await _tripDirectoryIn(_cacheDirectory, tripId)).path}/$id.jpg');

  Future<File?> _existingFullResFile(String tripId, String id) async {
    await _prepareTrip(tripId);
    for (final file in [await _durableFile(tripId, id), await _cacheFile(tripId, id)]) {
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<File> _downloadToCache(String tripId, String id, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') throw ArgumentError.value(url, 'url', 'Only https downloads are allowed');

    final target = await _cacheFile(tripId, id);
    final response = await _download(uri).timeout(_responseTimeout);
    await _writeAtomically(target, (temp) => _streamToFile(response, temp, uri));
    _logger.d('Downloaded full-resolution image $id');
    return target;
  }

  /// Streams the body to [file] without buffering it, failing if it is too large, stalls, or takes too long.
  Future<void> _streamToFile(GalleryDownloadResponse response, File file, Uri uri) async {
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > _maxDownloadBytes) {
      throw HttpException('Download of $declaredLength bytes exceeds the $_maxDownloadBytes byte limit', uri: uri);
    }

    final elapsed = Stopwatch()..start();
    final sink = file.openWrite();
    var received = 0;
    try {
      // Leaving the loop by throwing cancels the subscription, which closes the connection.
      await for (final chunk in response.bytes.timeout(_idleTimeout)) {
        received += chunk.length;
        if (received > _maxDownloadBytes) {
          throw HttpException('Download exceeds the $_maxDownloadBytes byte limit', uri: uri);
        }
        // The idle timeout guarantees chunks keep arriving, so checking here bounds the total time too.
        if (elapsed.elapsed > _downloadTimeout) throw TimeoutException('Download took too long', _downloadTimeout);
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
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

  Future<void> _prepareTrip(String tripId) => _tripPreparations.putIfAbsent(tripId, () async {
    await _deleteStaleTempFiles(tripId);
    await _runLegacyMigration(tripId);
  });

  /// Removes `.part` files left by a crash mid-write. Runs before this instance writes anything for the trip, so
  /// every temp file it finds is stale.
  Future<void> _deleteStaleTempFiles(String tripId) async {
    try {
      for (final directory in await _tripDirectories(tripId)) {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list()) {
          if (entity is File && entity.path.endsWith('.part')) await entity.delete();
        }
      }
    } catch (error, stackTrace) {
      _logger.w('Could not clean up temp files for trip $tripId', error: error, stackTrace: stackTrace);
    }
  }

  /// Moves originals from the legacy Hive box into durable files. Photos whose upload failed exist only there, so
  /// they are migrated rather than dropped. A lazy box keeps all the photos from being loaded into memory at once.
  Future<void> _runLegacyMigration(String tripId) async {
    final boxName = _legacyHighResBoxName(tripId);
    try {
      if (!await _hive.boxExists(boxName)) return;
      final box = await _hive.openLazyBox(boxName);
      for (final key in box.keys.whereType<String>()) {
        final target = await _durableFile(tripId, key);
        if (await target.exists() || await (await _cacheFile(tripId, key)).exists()) continue;
        final bytes = await box.get(key);
        if (bytes is List<int>) await _writeAtomically(target, (temp) => temp.writeAsBytes(bytes, flush: true));
      }
      await box.deleteFromDisk();
      _logger.i('Migrated legacy full-resolution cache for trip $tripId');
    } catch (error, stackTrace) {
      _logger.e('Legacy full-resolution migration failed for trip $tripId', error: error, stackTrace: stackTrace);
    }
  }

  static Future<GalleryDownloadResponse> _httpDownload(Uri url) async {
    final client = HttpClient()..connectionTimeout = _connectionTimeout;
    try {
      final request = await client.getUrl(url);
      // A redirect could lead off https, so it is treated as a failure instead of followed.
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status ${response.statusCode}', uri: url);
      }
      // A non-forced close lets this response finish streaming, then frees the client.
      client.close();
      return GalleryDownloadResponse(
        contentLength: response.contentLength >= 0 ? response.contentLength : null,
        bytes: response,
      );
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }
}
