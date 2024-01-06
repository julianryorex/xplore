import 'dart:io';

import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Fetches images from either cache or GCP
/// TODO: add GCP Storage fetch
class GalleryRepository {
  late final HiveInterface _hive;
  late final Logger _logger;

  GalleryRepository({HiveInterface? hiveInterface}) {
    _hive = hiveInterface ?? Hive;
    _logger = createLogger('GalleryRepo');
  }

  static const metadataBoxName = 'gallery-meta';
  static const highResBoxName = 'gallery-res';

  Future<Map<String, ImageModel>> loadImgFromCache() async {
    final Map<String, ImageModel> imgMap = {};

    final box = await _hive.openBox(metadataBoxName);
    for (String imageId in box.keys) {
      final ImageModel imageModel = box.get(imageId);
      imgMap.addAll({imageId: imageModel});
    }

    return imgMap;
  }

  /// Caches `ImageModel` to Hive (w/ compressed image)
  Future<void> cacheMetadata(ImageModel imageModel) async {
    try {
      final box = await _hive.openBox(metadataBoxName);
      await box.put(imageModel.id, imageModel);
    } catch (err) {
      Future.error(err);
    }
  }

  /// Caches the actual non-compresed image in hive
  Future<void> cacheHighResImage(String id, File file) async {
    try {
      final highResImage = await file.readAsBytes();
      final box = await _hive.openBox(highResBoxName);
      await box.put(id, highResImage);
      _logger.d('Cached high resolution image $id');
    } catch (err) {
      Future.error(err);
    }
  }

  Future<void> reset() async {
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
