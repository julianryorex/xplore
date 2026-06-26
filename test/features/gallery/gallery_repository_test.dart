// FEAT-014: gallery Hive boxes are namespaced per trip so one trip's cached
// photos never bleed into another. These tests drive a real Hive (temp dir,
// same setup as `image_model_adapter_test.dart`) and assert that switching the
// active trip isolates the metadata and high-res caches.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/models/image_models_adapters.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_gallery_repo_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ImageModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EUploadStatusAdapter());
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  ImageModel image(String id) => ImageModel(
    id: id,
    createdAt: DateTime.utc(2024),
    lowResImage: Uint8List.fromList([1, 2, 3]),
    isUploading: EUploadStatus.complete,
  );

  group('GalleryRepository trip scoping', () {
    test('returns empty and no-ops when no trip is active', () async {
      final repo = GalleryRepository();

      await repo.cacheMetadata(image('a'));

      expect(await repo.loadImgFromCache(), isEmpty);
      expect(await repo.loadHighResImage('a'), isNull);
    });

    test("keeps each trip's metadata cache isolated", () async {
      final repo = GalleryRepository();

      repo.setTrip('trip-a');
      await repo.cacheMetadata(image('a1'));

      // Switching to another trip surfaces none of trip-a's photos.
      repo.setTrip('trip-b');
      expect(await repo.loadImgFromCache(), isEmpty);

      await repo.cacheMetadata(image('b1'));
      expect((await repo.loadImgFromCache()).keys.toList(), ['b1']);

      // Switching back to trip-a restores its own cache.
      repo.setTrip('trip-a');
      expect((await repo.loadImgFromCache()).keys.toList(), ['a1']);
    });

    test('high-res images are scoped to the active trip box', () async {
      final repo = GalleryRepository();
      final file = File('${tempDir.path}/hi.bin')..writeAsBytesSync([9, 8, 7]);

      repo.setTrip('trip-a');
      await repo.cacheHighResImage('hi', file);
      expect(await repo.loadHighResImage('hi'), Uint8List.fromList([9, 8, 7]));

      repo.setTrip('trip-b');
      expect(await repo.loadHighResImage('hi'), isNull);
    });
  });
}
