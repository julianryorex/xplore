// Round-trip tests for `GalleryRepository` against a real `hive_ce` store.
//
// These exercise the byte-blob + typed-adapter box paths that back the gallery
// cache. They double as the migration guard for the Hive -> hive_ce swap: the
// repository writes an `ImageModel` (via the hand-written `TypeAdapter`) and a
// raw `Uint8List` high-res blob, then reads both back through freshly opened
// boxes to prove hive_ce persists and restores them unchanged.

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
  late GalleryRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_gallery_repo_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ImageModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EUploadStatusAdapter());
    repository = GalleryRepository();
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

  test('cacheMetadata persists an ImageModel that loadImgFromCache restores', () async {
    final model = buildModel('img-1');

    await repository.cacheMetadata(model);
    final loaded = await repository.loadImgFromCache();

    expect(loaded.keys, ['img-1']);
    expect(loaded['img-1'], model);
    expect(loaded['img-1']!.lowResImage, model.lowResImage);
  });

  test('cacheHighResImage stores the original bytes verbatim', () async {
    final bytes = Uint8List.fromList(List<int>.generate(256, (i) => i % 256));
    final file = File('${tempDir.path}/high-res.bin')..writeAsBytesSync(bytes);

    await repository.cacheHighResImage('img-1', file);

    final box = await Hive.openBox(GalleryRepository.highResBoxName);
    expect(box.get('img-1'), bytes);
  });

  test('reset clears both the metadata and high-res boxes', () async {
    final file = File('${tempDir.path}/high-res.bin')..writeAsBytesSync(Uint8List.fromList([9, 8, 7]));
    await repository.cacheMetadata(buildModel('img-1'));
    await repository.cacheHighResImage('img-1', file);

    await repository.reset();

    expect(await repository.loadImgFromCache(), isEmpty);
    final highResBox = await Hive.openBox(GalleryRepository.highResBoxName);
    expect(highResBox.isEmpty, isTrue);
  });
}
