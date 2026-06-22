import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/gallery/models/image_models.freezed.dart';

// NOTE: Hive TypeAdapters for these types are hand-written in
// `image_models_adapters.dart` (typeId 1 for ImageModel, typeId 2 for
// EUploadStatus). Keep the field order there in sync with this class.
@freezed
abstract class ImageModel with _$ImageModel {
  const factory ImageModel({
    required String id,
    required DateTime createdAt,
    required Uint8List lowResImage,
    required EUploadStatus isUploading,
    String? downloadUrl,
  }) = _ImageModel;
}

enum EUploadStatus {
  notStarted,
  uploading,
  complete,
  failed,
}
