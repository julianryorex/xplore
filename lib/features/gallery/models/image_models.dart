import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/gallery/models/image_models.freezed.dart';

@freezed
class ImageModel with _$ImageModel {
  const factory ImageModel({
    required String url,
    required DateTime createdAt,
    bool? isUploading,
    Uint8List? bytes,
  }) = _ImageModel;
}
