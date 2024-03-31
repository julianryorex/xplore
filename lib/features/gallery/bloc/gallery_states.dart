part of 'gallery_cubit.dart';

@freezed
class GalleryState with _$GalleryState {
  const factory GalleryState({
    @Default(EBlocStatus.loading) EBlocStatus status,
    @Default({}) Map<String, ImageModel> imageMap,
  }) = _GalleryState;
}
