import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:xplore/features/gallery/models/image_models.dart';

/// Hand-written Hive [TypeAdapter]s for the gallery models.
///
/// These previously lived in a `hive_generator`-generated part file. That
/// generator (now discontinued) capped the analyzer below v7 and blocked
/// upgrading freezed/build_runner to their latest releases, so the adapters are
/// maintained by hand here. The binary layout (typeIds + field indices) matches
/// the original generated output to keep existing on-disk data readable.
class ImageModelAdapter extends TypeAdapter<ImageModel> {
  @override
  final int typeId = 1;

  @override
  ImageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageModel(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      lowResImage: fields[2] as Uint8List,
      isUploading: fields[3] as EUploadStatus,
      downloadUrl: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.lowResImage)
      ..writeByte(3)
      ..write(obj.isUploading)
      ..writeByte(4)
      ..write(obj.downloadUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

class EUploadStatusAdapter extends TypeAdapter<EUploadStatus> {
  @override
  final int typeId = 2;

  @override
  EUploadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EUploadStatus.notStarted;
      case 1:
        return EUploadStatus.uploading;
      case 2:
        return EUploadStatus.complete;
      case 3:
        return EUploadStatus.failed;
      default:
        return EUploadStatus.notStarted;
    }
  }

  @override
  void write(BinaryWriter writer, EUploadStatus obj) {
    switch (obj) {
      case EUploadStatus.notStarted:
        writer.writeByte(0);
        break;
      case EUploadStatus.uploading:
        writer.writeByte(1);
        break;
      case EUploadStatus.complete:
        writer.writeByte(2);
        break;
      case EUploadStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EUploadStatusAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
