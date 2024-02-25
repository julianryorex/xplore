part of 'gallery_cubit.dart';

abstract class GalleryStates {}

class InitialGalleryState extends GalleryStates {}

@freezed
class LoadedGalleryState extends GalleryStates with _$LoadedGalleryState {
  const factory LoadedGalleryState({
    @Default([]) List<ImageModel> imageList,
  }) = _LoadedGalleryState;
}
