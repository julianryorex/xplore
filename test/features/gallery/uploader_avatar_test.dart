import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';

ImageModel _photo(String id, {String? uploaderUid, String? uploaderName}) => ImageModel(
  id: id,
  createdAt: DateTime(2025, 9, 16),
  lowResImage: Uint8List(0),
  isUploading: EUploadStatus.complete,
  uploaderUid: uploaderUid,
  uploaderName: uploaderName,
);

void main() {
  test('distinctUploaders groups by uid even when the stamped name changed between uploads', () {
    final uploaders = distinctUploaders([
      _photo('1', uploaderUid: 'alex', uploaderName: 'Alexander'),
      _photo('2', uploaderUid: 'alex', uploaderName: 'Alex'),
      _photo('3', uploaderUid: 'mara', uploaderName: 'Alex'),
    ], currentUid: 'me');

    expect(uploaders.map((uploader) => uploader.uid), ['alex', 'mara']);
  });

  test('distinctUploaders falls back to the name for legacy photos without a uid', () {
    final uploaders = distinctUploaders([
      _photo('1', uploaderName: 'Mara'),
      _photo('2', uploaderName: 'Mara'),
      _photo('3', uploaderName: 'Jon'),
    ], currentUid: 'me');

    expect(uploaders.map((uploader) => uploader.label), ['Mara', 'Jon']);
  });
}
