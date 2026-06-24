// Round-trip tests for the hand-written Hive adapters in
// `image_models_adapters.dart`.
//
// These adapters replaced generated `hive_generator` output and the binary
// layout (typeIds + field indices) is maintained by hand. A mismatch silently
// corrupts every cached gallery photo on disk, so we persist a real value
// through a Hive box and assert it reads back byte-for-byte.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/models/image_models_adapters.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ImageModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EUploadStatusAdapter());
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('persists and reloads an ImageModel unchanged across box reopen', () async {
    final original = ImageModel(
      id: 'img-1',
      createdAt: DateTime.utc(2023, 6, 15, 8, 30),
      lowResImage: Uint8List.fromList(List<int>.generate(64, (i) => i)),
      isUploading: EUploadStatus.complete,
      downloadUrl: 'https://example.com/img-1.jpg',
    );

    final box = await Hive.openBox<ImageModel>('gallery');
    await box.put(original.id, original);
    await box.close();

    final reopened = await Hive.openBox<ImageModel>('gallery');
    final restored = reopened.get('img-1');

    expect(restored, original);
    expect(restored!.lowResImage, original.lowResImage);
  });

  test('preserves a null downloadUrl', () async {
    final original = ImageModel(
      id: 'img-2',
      createdAt: DateTime.utc(2024),
      lowResImage: Uint8List.fromList([1, 2, 3]),
      isUploading: EUploadStatus.uploading,
    );

    final box = await Hive.openBox<ImageModel>('gallery');
    await box.put(original.id, original);

    expect(box.get('img-2')!.downloadUrl, isNull);
  });

  test('maps every EUploadStatus to a stable byte tag', () async {
    final box = await Hive.openBox<EUploadStatus>('status');

    for (final status in EUploadStatus.values) {
      await box.put(status.name, status);
    }
    await box.close();

    final reopened = await Hive.openBox<EUploadStatus>('status');
    for (final status in EUploadStatus.values) {
      expect(reopened.get(status.name), status);
    }
  });
}
