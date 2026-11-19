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

    /// Firebase UID of the member who added the photo. `null` for photos cached
    /// before attribution existed.
    String? uploaderUid,

    /// The uploader's first name at upload time. Stored on the photo because
    /// members cannot read each other's profiles.
    String? uploaderName,

    /// SHA-256 of the original file (see `photoContentHash`), used to skip
    /// photos already in the trip. `null` for photos added before it existed.
    String? contentHash,
  }) = _ImageModel;
}

enum EUploadStatus { notStarted, uploading, complete, failed }
