// Tests for `GalleryRepository` against a real `hive_ce` store and temp-dir file caches.
//
// Covered:
//   1. Metadata persistence round-trip through the hand-written `TypeAdapter` (the Hive -> hive_ce guard).
//   2. Trip scoping (FEAT-014) — caches are namespaced per trip.
//   3. Full-resolution originals as plain files — local adds in durable storage, downloads in the purgeable cache,
//      download-once, atomic writes, stale temp file cleanup.
//   4. Download safety — https only, size cap, stall timeout.
//   5. Migration of legacy `gallery-res-<tripId>` Hive boxes into files.
//   6. Saved-to-Photos ids persistence, `closeTrip` and `reset`.

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
  late Directory durableDir;
  late Directory cacheDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_gallery_repo_test');
    durableDir = Directory('${tempDir.path}/support')..createSync();
    cacheDir = Directory('${tempDir.path}/caches')..createSync();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ImageModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EUploadStatusAdapter());
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  GalleryRepository buildRepository({
    GalleryDownloader? download,
    Duration idleTimeout = const Duration(seconds: 30),
    int maxDownloadBytes = 1024,
  }) => GalleryRepository(
    durableDirectory: () async => durableDir,
    cacheDirectory: () async => cacheDir,
    download: download ?? (url) async => throw StateError('Unexpected download of $url'),
    idleTimeout: idleTimeout,
    maxDownloadBytes: maxDownloadBytes,
  );

  GalleryDownloadResponse response(List<int> bytes, {int? contentLength}) =>
      GalleryDownloadResponse(contentLength: contentLength ?? bytes.length, bytes: Stream.value(bytes));

  ImageModel buildModel(String id) => ImageModel(
    id: id,
    createdAt: DateTime.utc(2024, 1, 2, 3, 4),
    lowResImage: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    isUploading: EUploadStatus.complete,
    downloadUrl: 'https://example.com/$id.jpg',
  );

  File sourceFile(String name, List<int> bytes) => File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  List<FileSystemEntity> partFiles() => [
    durableDir,
    cacheDir,
  ].expand((dir) => dir.listSync(recursive: true)).where((entity) => entity.path.endsWith('.part')).toList();

  const url = 'https://example.com/img-1.jpg';

  group('metadata', () {
    test('cacheMetadata persists an ImageModel that loadImgFromCache restores', () async {
      final repository = buildRepository();
      final model = buildModel('img-1');

      await repository.cacheMetadata('trip-1', model);
      final loaded = await repository.loadImgFromCache('trip-1');

      expect(loaded.keys, ['img-1']);
      expect(loaded['img-1'], model);
      expect(loaded['img-1']!.lowResImage, model.lowResImage);
    });

    test('loadImgFromCache skips entries that are not ImageModels', () async {
      final repository = buildRepository();
      await repository.cacheMetadata('trip-1', buildModel('img-1'));
      await (await Hive.openBox('${GalleryRepository.metadataBoxPrefix}-trip-1')).put('junk', 42);

      expect((await repository.loadImgFromCache('trip-1')).keys, ['img-1']);
    });
  });

  test("keeps each trip's metadata, full-res files and saved ids isolated", () async {
    final repository = buildRepository();
    await repository.cacheMetadata('trip-a', buildModel('a1'));
    await repository.cacheFullRes('trip-a', 'a1', sourceFile('a1.jpg', [1, 2]));
    await repository.markPhotoSaved('trip-a', 'a1');

    expect(await repository.loadImgFromCache('trip-b'), isEmpty);
    expect(await repository.fullResFile('trip-b', 'a1'), isNull);
    expect(await repository.loadSavedPhotoIds('trip-b'), isEmpty);

    expect((await repository.loadImgFromCache('trip-a')).keys, ['a1']);
    expect(await (await repository.fullResFile('trip-a', 'a1'))!.readAsBytes(), [1, 2]);
    expect(await repository.loadSavedPhotoIds('trip-a'), {'a1'});
  });

  group('full-resolution files', () {
    test('cacheFullRes copies the source into durable storage so it survives the source', () async {
      final repository = buildRepository();
      final source = sourceFile('picked.jpg', [9, 8, 7]);

      final cached = await repository.cacheFullRes('trip-1', 'img-1', source);
      source.deleteSync();

      expect(cached.path, '${durableDir.path}/gallery/trip-1/img-1.jpg');
      expect((await repository.fullResFile('trip-1', 'img-1'))!.readAsBytesSync(), [9, 8, 7]);
    });

    test('releaseUploadedOriginal moves a durable original into the purgeable cache', () async {
      final repository = buildRepository();
      await repository.cacheFullRes('trip-1', 'img-1', sourceFile('picked.jpg', [3]));

      await repository.releaseUploadedOriginal('trip-1', 'img-1');

      final file = await repository.fullResFile('trip-1', 'img-1');
      expect(file!.path, '${cacheDir.path}/gallery/trip-1/img-1.jpg');
      expect(file.readAsBytesSync(), [3]);
      expect(File('${durableDir.path}/gallery/trip-1/img-1.jpg').existsSync(), isFalse);
    });

    test('fetchAndCacheFullRes downloads once into the cache, shares concurrent calls, then serves it', () async {
      var downloads = 0;
      final gate = Completer<void>();
      final repository = buildRepository(
        download: (url) async {
          downloads++;
          await gate.future;
          return response([4, 5, 6]);
        },
      );

      final first = repository.fetchAndCacheFullRes('trip-1', 'img-1', url);
      final second = repository.fetchAndCacheFullRes('trip-1', 'img-1', url);
      gate.complete();
      final files = await Future.wait([first, second]);
      final third = await repository.fetchAndCacheFullRes('trip-1', 'img-1', url);

      expect(downloads, 1);
      expect(files[0].path, '${cacheDir.path}/gallery/trip-1/img-1.jpg');
      expect(files[0].readAsBytesSync(), [4, 5, 6]);
      expect(files[1].path, files[0].path);
      expect(third.path, files[0].path);
    });

    test('a failed download rethrows and leaves no file behind, so a retry can succeed', () async {
      var fail = true;
      final repository = buildRepository(
        download: (url) async => fail ? throw const HttpException('boom') : response([1]),
      );

      await expectLater(repository.fetchAndCacheFullRes('trip-1', 'img-1', url), throwsA(isA<HttpException>()));
      expect(await repository.fullResFile('trip-1', 'img-1'), isNull);
      expect(partFiles(), isEmpty);

      fail = false;
      expect((await repository.fetchAndCacheFullRes('trip-1', 'img-1', url)).readAsBytesSync(), [1]);
    });

    test('stale temp files from an earlier crash are deleted when the trip is first used', () async {
      final durableTemp = File('${durableDir.path}/gallery/trip-1/a.jpg.1.part')..createSync(recursive: true);
      final cacheTemp = File('${cacheDir.path}/gallery/trip-1/b.jpg.2.part')..createSync(recursive: true);

      await buildRepository().fullResFile('trip-1', 'a');

      expect(durableTemp.existsSync(), isFalse);
      expect(cacheTemp.existsSync(), isFalse);
    });
  });

  group('download safety', () {
    Future<void> expectRejected(GalleryRepository repository, Matcher error, {String downloadUrl = url}) async {
      await expectLater(repository.fetchAndCacheFullRes('trip-1', 'img-1', downloadUrl), throwsA(error));
      expect(await repository.fullResFile('trip-1', 'img-1'), isNull);
      expect(partFiles(), isEmpty);
    }

    test('refuses non-https urls without downloading', () async {
      await expectRejected(buildRepository(), isA<ArgumentError>(), downloadUrl: 'http://example.com/img-1.jpg');
    });

    test('rejects a response whose declared length exceeds the cap', () async {
      final repository = buildRepository(download: (url) async => response([1], contentLength: 2048));
      await expectRejected(repository, isA<HttpException>());
    });

    test('rejects a body that streams past the cap when no length was declared', () async {
      final repository = buildRepository(
        download: (url) async => GalleryDownloadResponse(
          contentLength: null,
          bytes: Stream.fromIterable([List.filled(600, 0), List.filled(600, 0)]),
        ),
      );
      await expectRejected(repository, isA<HttpException>());
    });

    test('a stalled download times out and is not shared with later requests', () async {
      final stalled = StreamController<List<int>>();
      var downloads = 0;
      final repository = buildRepository(
        idleTimeout: const Duration(milliseconds: 50),
        download: (url) async {
          downloads++;
          return downloads == 1 ? GalleryDownloadResponse(contentLength: null, bytes: stalled.stream) : response([7]);
        },
      );

      await expectRejected(repository, isA<TimeoutException>());
      expect((await repository.fetchAndCacheFullRes('trip-1', 'img-1', url)).readAsBytesSync(), [7]);
      await stalled.close();
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

    test('moves legacy originals into durable files, keeps existing files and deletes the box', () async {
      final existing = File('${durableDir.path}/gallery/trip-1/kept.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0]);
      await seedLegacyBox('trip-1', {
        'only-local': [1, 2, 3],
        'kept': [7, 7],
      });

      final migrated = await buildRepository().fullResFile('trip-1', 'only-local');

      expect(migrated!.path, '${durableDir.path}/gallery/trip-1/only-local.jpg');
      expect(migrated.readAsBytesSync(), [1, 2, 3]);
      expect(existing.readAsBytesSync(), [0]);
      expect(await Hive.boxExists('${GalleryRepository.legacyHighResBoxPrefix}-trip-1'), isFalse);
    });

    test('a broken legacy box does not break the gallery', () async {
      // Leaving the box open as a regular box makes opening it lazily throw.
      final box = await Hive.openBox('${GalleryRepository.legacyHighResBoxPrefix}-trip-1');
      await box.put('img-1', Uint8List.fromList([1]));
      final repository = buildRepository();

      expect(await repository.fullResFile('trip-1', 'img-1'), isNull);
      expect(await repository.cacheFullRes('trip-1', 'img-2', sourceFile('two.jpg', [2])), isNotNull);
    });
  });

  test('saved-to-Photos ids persist across repository instances', () async {
    await buildRepository().markPhotoSaved('trip-1', 'img-1');
    await Hive.close();

    expect(await buildRepository().loadSavedPhotoIds('trip-1'), {'img-1'});
  });

  group('closeTrip', () {
    test("closes the trip's boxes and later calls reopen them with their data", () async {
      final repository = buildRepository();
      await repository.cacheMetadata('trip-1', buildModel('img-1'));
      await repository.markPhotoSaved('trip-1', 'img-1');

      await repository.closeTrip('trip-1');

      expect(Hive.isBoxOpen('${GalleryRepository.metadataBoxPrefix}-trip-1'), isFalse);
      expect(Hive.isBoxOpen('${GalleryRepository.savedToPhotosBoxPrefix}-trip-1'), isFalse);
      expect((await repository.loadImgFromCache('trip-1')).keys, ['img-1']);
      expect(await repository.loadSavedPhotoIds('trip-1'), {'img-1'});
    });

    test('a write racing a close still lands', () async {
      final repository = buildRepository();
      await repository.loadImgFromCache('trip-1');

      await Future.wait([repository.closeTrip('trip-1'), repository.cacheMetadata('trip-1', buildModel('img-1'))]);

      expect((await repository.loadImgFromCache('trip-1')).keys, ['img-1']);
    });
  });

  test('reset clears metadata, full-res files and saved ids for that trip only', () async {
    final repository = buildRepository(download: (url) async => response([6]));
    await repository.cacheFullRes('trip-other', 'other', sourceFile('other.jpg', [5]));

    await repository.cacheMetadata('trip-1', buildModel('img-1'));
    await repository.cacheFullRes('trip-1', 'img-1', sourceFile('one.jpg', [1]));
    await repository.fetchAndCacheFullRes('trip-1', 'img-2', url);
    await repository.markPhotoSaved('trip-1', 'img-1');

    await repository.reset('trip-1');

    expect(await repository.loadImgFromCache('trip-1'), isEmpty);
    expect(await repository.fullResFile('trip-1', 'img-1'), isNull);
    expect(Directory('${durableDir.path}/gallery/trip-1').existsSync(), isFalse);
    expect(Directory('${cacheDir.path}/gallery/trip-1').existsSync(), isFalse);
    expect(await repository.loadSavedPhotoIds('trip-1'), isEmpty);
    expect(await repository.fullResFile('trip-other', 'other'), isNotNull);
  });
}
