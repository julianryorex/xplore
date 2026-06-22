part of 'gallery_cubit.dart';

@freezed
abstract class GalleryState with _$GalleryState {
  const factory GalleryState({
    @Default(EBlocStatus.loaded) EBlocStatus status,
    @Default({}) Map<String, ImageModel> imageMap,
  }) = _GalleryState;
}
