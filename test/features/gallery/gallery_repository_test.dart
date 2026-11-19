// Tests for `GalleryRepository` against a real `hive_ce` store and a temp-dir file cache.
//
// Covered:
//   1. Metadata persistence round-trip through the hand-written `TypeAdapter` (the Hive -> hive_ce guard).
//   2. Trip scoping (FEAT-014) — caches are namespaced per trip and no-op when no trip is active.
//   3. Full-resolution originals as plain files — copy-on-cache, download-once, atomic writes.
//   4. Migration of legacy `gallery-res-<tripId>` Hive boxes into files.
//   5. Saved-to-Photos ids persistence and `reset`.

import 'dart:async';
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
  late Directory filesDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_gallery_repo_test');
    filesDir = Directory('${tempDir.path}/support')..createSync();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ImageModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EUploadStatusAdapter());
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  GalleryRepository buildRepository({GalleryDownloader? download}) => GalleryRepository(
    baseDirectory: () async => filesDir,
    download: download ?? (url) async => throw StateError('Unexpected download of $url'),
  );

  ImageModel buildModel(String id) => ImageModel(
    id: id,
    createdAt: DateTime.utc(2024, 1, 2, 3, 4),
    lowResImage: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    isUploading: EUploadStatus.complete,
    downloadUrl: 'https://example.com/$id.jpg',
  );

  File sourceFile(String name, List<int> bytes) => File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  List<FileSystemEntity> partFiles() =>
      filesDir.listSync(recursive: true).where((entity) => entity.path.endsWith('.part')).toList();

  group('metadata', () {
    test('cacheMetadata persists an ImageModel that loadImgFromCache restores', () async {
      final repository = buildRepository()..setTrip('trip-1');
      final model = buildModel('img-1');

      await repository.cacheMetadata(model);
      final loaded = await repository.loadImgFromCache();

      expect(loaded.keys, ['img-1']);
      expect(loaded['img-1'], model);
      expect(loaded['img-1']!.lowResImage, model.lowResImage);
    });

    test('loadImgFromCache skips entries that are not ImageModels', () async {
      final repository = buildRepository()..setTrip('trip-1');
      await repository.cacheMetadata(buildModel('img-1'));
      await (await Hive.openBox('${GalleryRepository.metadataBoxPrefix}-trip-1')).put('junk', 42);

      expect((await repository.loadImgFromCache()).keys, ['img-1']);
    });
  });

  group('trip scoping', () {
    test('returns empty and no-ops when no trip is active', () async {
      final repository = buildRepository();

      await repository.cacheMetadata(buildModel('a'));
      await repository.markPhotoSaved('a');

      expect(await repository.loadImgFromCache(), isEmpty);
      expect(await repository.cacheFullRes('a', sourceFile('a.jpg', [1])), isNull);
      expect(await repository.fullResFile('a'), isNull);
      expect(await repository.loadSavedPhotoIds(), isEmpty);
    });

    test("keeps each trip's metadata, full-res files and saved ids isolated", () async {
      final repository = buildRepository()..setTrip('trip-a');
      await repository.cacheMetadata(buildModel('a1'));
      await repository.cacheFullRes('a1', sourceFile('a1.jpg', [1, 2]));
      await repository.markPhotoSaved('a1');

      repository.setTrip('trip-b');
      expect(await repository.loadImgFromCache(), isEmpty);
      expect(await repository.fullResFile('a1'), isNull);
      expect(await repository.loadSavedPhotoIds(), isEmpty);

      repository.setTrip('trip-a');
      expect((await repository.loadImgFromCache()).keys, ['a1']);
      expect(await (await repository.fullResFile('a1'))!.readAsBytes(), [1, 2]);
      expect(await repository.loadSavedPhotoIds(), {'a1'});
    });
  });

  group('full-resolution files', () {
    test('cacheFullRes copies the source so the cache survives its deletion', () async {
      final repository = buildRepository()..setTrip('trip-1');
      final source = sourceFile('picked.jpg', [9, 8, 7]);

      final cached = await repository.cacheFullRes('img-1', source);
      source.deleteSync();

      expect(cached!.path, '${filesDir.path}/gallery/trip-1/img-1.jpg');
      expect((await repository.fullResFile('img-1'))!.readAsBytesSync(), [9, 8, 7]);
    });

    test('fetchAndCacheFullRes downloads once, shares concurrent calls and then serves the cache', () async {
      var downloads = 0;
      final gate = Completer<void>();
      final repository = buildRepository(
        download: (url) async {
          downloads++;
          await gate.future;
          return Uint8List.fromList([4, 5, 6]);
        },
      )..setTrip('trip-1');

      final first = repository.fetchAndCacheFullRes('img-1', 'https://example.com/img-1.jpg');
      final second = repository.fetchAndCacheFullRes('img-1', 'https://example.com/img-1.jpg');
      gate.complete();
      final files = await Future.wait([first, second]);
      final third = await repository.fetchAndCacheFullRes('img-1', 'https://example.com/img-1.jpg');

      expect(downloads, 1);
      expect(files[0]!.readAsBytesSync(), [4, 5, 6]);
      expect(files[1]!.path, files[0]!.path);
      expect(third!.path, files[0]!.path);
    });

    test('a failed download rethrows and leaves no file behind, so a retry can succeed', () async {
      var fail = true;
      final repository = buildRepository(
        download: (url) async => fail ? throw const HttpException('boom') : Uint8List.fromList([1]),
      )..setTrip('trip-1');

      await expectLater(repository.fetchAndCacheFullRes('img-1', 'u'), throwsA(isA<HttpException>()));
      expect(await repository.fullResFile('img-1'), isNull);
      expect(partFiles(), isEmpty);

      fail = false;
      expect((await repository.fetchAndCacheFullRes('img-1', 'u'))!.readAsBytesSync(), [1]);
    });
  });

  group('legacy Hive migration', () {
    Future<void> seedLegacyBox(String tripId, Map<String, List<int>> photos) async {
      final box = await Hive.openBox('${GalleryRepository.legacyHighResBoxPrefix}-$tripId');
      for (final entry in photos.entries) {
        await box.put(entry.key, Uint8List.fromList(entry.value));
      }
      await box.close();
    }

    test('moves legacy originals into files, keeps existing files and deletes the box', () async {
      final existing = File('${filesDir.path}/gallery/trip-1/kept.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0]);
      await seedLegacyBox('trip-1', {
        'only-local': [1, 2, 3],
        'kept': [7, 7],
      });
      final repository = buildRepository()..setTrip('trip-1');

      expect((await repository.fullResFile('only-local'))!.readAsBytesSync(), [1, 2, 3]);
      expect(existing.readAsBytesSync(), [0]);
      expect(await Hive.boxExists('${GalleryRepository.legacyHighResBoxPrefix}-trip-1'), isFalse);
    });

    test('a broken legacy box does not break the gallery', () async {
      // Leaving the box open as a regular box makes opening it lazily throw.
      final box = await Hive.openBox('${GalleryRepository.legacyHighResBoxPrefix}-trip-1');
      await box.put('img-1', Uint8List.fromList([1]));
      final repository = buildRepository()..setTrip('trip-1');

      expect(await repository.fullResFile('img-1'), isNull);
      expect(await repository.cacheFullRes('img-2', sourceFile('two.jpg', [2])), isNotNull);
    });
  });

  group('saved-to-Photos ids', () {
    test('persist across repository instances', () async {
      await (buildRepository()..setTrip('trip-1')).markPhotoSaved('img-1');
      await Hive.close();

      final reopened = buildRepository()..setTrip('trip-1');
      expect(await reopened.loadSavedPhotoIds(), {'img-1'});
    });
  });

  test('reset clears metadata, full-res files and saved ids for the active trip only', () async {
    final repository = buildRepository()..setTrip('trip-other');
    await repository.cacheFullRes('other', sourceFile('other.jpg', [5]));

    repository.setTrip('trip-1');
    await repository.cacheMetadata(buildModel('img-1'));
    await repository.cacheFullRes('img-1', sourceFile('one.jpg', [1]));
    await repository.markPhotoSaved('img-1');

    await repository.reset();

    expect(await repository.loadImgFromCache(), isEmpty);
    expect(await repository.fullResFile('img-1'), isNull);
    expect(Directory('${filesDir.path}/gallery/trip-1').existsSync(), isFalse);
    expect(await repository.loadSavedPhotoIds(), isEmpty);

    repository.setTrip('trip-other');
    expect(await repository.fullResFile('other'), isNotNull);
  });
}
