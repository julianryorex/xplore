import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';

part '../../../generated/features/gallery/models/image_models.freezed.dart';
part '../../../generated/features/gallery/models/image_models.g.dart';

@freezed
@HiveType(typeId: 1)
class ImageModel with _$ImageModel {
  const factory ImageModel({
    @HiveField(0) required String id,
    @HiveField(1) required DateTime createdAt,
    @HiveField(2) required Uint8List lowResImage,
    @HiveField(3) required EUploadStatus isUploading,
    @HiveField(4) String? downloadUrl,
  }) = _ImageModel;
}

@HiveType(typeId: 2)
enum EUploadStatus {
  @HiveField(0)
  notStarted,

  @HiveField(1)
  uploading,

  @HiveField(2)
  complete,

  @HiveField(3)
  failed,
}
