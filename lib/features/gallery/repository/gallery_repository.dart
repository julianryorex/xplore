import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Reads and writes cached gallery images for the active trip.
/// Cloud uploads/downloads are coordinated by [GalleryCubit].
class GalleryRepository {
  late final HiveInterface _hive;
  late final Logger _logger;

  /// Active trip scope. Hive box names are namespaced per trip so one trip's
  /// cached photos never bleed into another. `null` means no trip is active yet,
  /// in which case reads return empty and writes are no-ops.
  String? _tripId;

  GalleryRepository({HiveInterface? hiveInterface}) {
    _hive = hiveInterface ?? Hive;
    _logger = createLogger('GalleryRepo');
  }

  static const metadataBoxPrefix = 'gallery-meta';
  static const highResBoxPrefix = 'gallery-res';

  /// Sets the active trip scope. Pass `null` to clear it (no trip active).
  void setTrip(String? tripId) => _tripId = tripId;

  String? get _metadataBoxName => _tripId == null ? null : '$metadataBoxPrefix-$_tripId';
  String? get _highResBoxName => _tripId == null ? null : '$highResBoxPrefix-$_tripId';

  Future<Map<String, ImageModel>> loadImgFromCache() async {
    final boxName = _metadataBoxName;
    if (boxName == null) return {};

    final Map<String, ImageModel> imgMap = {};

    final box = await _hive.openBox(boxName);
    for (String imageId in box.keys) {
      final ImageModel imageModel = box.get(imageId);
      imgMap.addAll({imageId: imageModel});
    }

    return imgMap;
  }

  /// Caches `ImageModel` to Hive (w/ compressed image)
  Future<void> cacheMetadata(ImageModel imageModel) async {
    final boxName = _metadataBoxName;
    if (boxName == null) return;
    try {
      final box = await _hive.openBox(boxName);
      await box.put(imageModel.id, imageModel);
    } catch (err) {
      Future.error(err);
    }
  }

  /// Caches the actual non-compressed image in hive
  Future<void> cacheHighResImage(String id, File file) async {
    final boxName = _highResBoxName;
    if (boxName == null) return;
    try {
      final highResImage = await file.readAsBytes();
      final box = await _hive.openBox(boxName);
      await box.put(id, highResImage);
      _logger.d('Cached high resolution image $id');
    } catch (err) {
      Future.error(err);
    }
  }

  /// Loads a cached high-resolution image for the active trip, or `null` when
  /// it is not cached (or no trip is active).
  Future<Uint8List?> loadHighResImage(String id) async {
    final boxName = _highResBoxName;
    if (boxName == null) return null;
    final box = await _hive.openBox(boxName);
    return box.get(id) as Uint8List?;
  }

  Future<void> reset() async {
    final metadataBoxName = _metadataBoxName;
    final highResBoxName = _highResBoxName;
    if (metadataBoxName == null || highResBoxName == null) return;
    try {
      final box1 = await _hive.openBox(metadataBoxName);
      final box2 = await _hive.openBox(highResBoxName);
      await box1.deleteFromDisk();
      await box2.deleteFromDisk();
      _logger.d('Deleted boxes in Hive');
    } catch (err) {
      Future.error(err);
    }
  }
}
