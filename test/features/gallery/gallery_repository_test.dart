// Tests for `GalleryRepository` against a real `hive_ce` store.
//
// Two concerns are covered:
//   1. Persistence round-trip — the repository writes an `ImageModel` (via the
//      hand-written `TypeAdapter`) and a raw `Uint8List` high-res blob, then
//      reads both back to prove hive_ce persists and restores them unchanged
//      (the Hive -> hive_ce migration guard).
//   2. Trip scoping (FEAT-014) — Hive boxes are namespaced per trip so one
//      trip's cached photos never bleed into another, and reads/writes no-op
//      when no trip is active.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/models/image_models_adapters.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  ImageModel buildModel(String id) => ImageModel(
    id: id,
    createdAt: DateTime.utc(2024, 1, 2, 3, 4),
    lowResImage: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    isUploading: EUploadStatus.complete,
    downloadUrl: 'https://example.com/$id.jpg',
  );

  ImageModel image(String id) => ImageModel(
    id: id,
    createdAt: DateTime.utc(2024),
    lowResImage: Uint8List.fromList([1, 2, 3]),
    isUploading: EUploadStatus.complete,
  );

  group('GalleryRepository persistence (hive_ce migration guard)', () {
    test('cacheMetadata persists an ImageModel that loadImgFromCache restores', () async {
      final repository = GalleryRepository()..setTrip('trip-1');
      final model = buildModel('img-1');

      await repository.cacheMetadata(model);
      final loaded = await repository.loadImgFromCache();

      expect(loaded.keys, ['img-1']);
      expect(loaded['img-1'], model);
      expect(loaded['img-1']!.lowResImage, model.lowResImage);
    });

    test('cacheHighResImage stores the original bytes verbatim', () async {
      final repository = GalleryRepository()..setTrip('trip-1');
      final bytes = Uint8List.fromList(List<int>.generate(256, (i) => i % 256));
      final file = File('${tempDir.path}/high-res.bin')..writeAsBytesSync(bytes);

      await repository.cacheHighResImage('img-1', file);

      expect(await repository.loadHighResImage('img-1'), bytes);
    });

    test('reset clears both the metadata and high-res boxes', () async {
      final repository = GalleryRepository()..setTrip('trip-1');
      final file = File('${tempDir.path}/high-res.bin')..writeAsBytesSync(Uint8List.fromList([9, 8, 7]));
      await repository.cacheMetadata(buildModel('img-1'));
      await repository.cacheHighResImage('img-1', file);

      await repository.reset();

      expect(await repository.loadImgFromCache(), isEmpty);
      expect(await repository.loadHighResImage('img-1'), isNull);
    });
  });

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
