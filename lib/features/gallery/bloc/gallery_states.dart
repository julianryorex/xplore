part of 'gallery_cubit.dart';

@freezed
abstract class GalleryState with _$GalleryState {
  const GalleryState._();

  const factory GalleryState({
    @Default(EBlocStatus.loaded) EBlocStatus status,
    @Default({}) Map<String, ImageModel> imageMap,

    /// Progress of the current or last "Save to Photos" run; `null` when none
    /// has run or the result was dismissed.
    PhotoSaveProgress? saveProgress,

    /// Ids of the trip's photos already saved to the Photos app from this device.
    @Default({}) Set<String> savedToPhotosIds,

    /// Whether the active trip's photos have arrived from the cloud at least
    /// once (or the attempt failed). Until then an empty album may just be unsynced.
    @Default(false) bool hasSyncedWithCloud,

    /// How many photos of the last pick were left out because the trip already
    /// has them. Cleared again after a few seconds.
    @Default(0) int duplicatesSkipped,
  }) = _GalleryState;

  /// Uploaded photos not yet saved to the Photos app from this device, newest
  /// first: what "Save all to Photos" would add.
  List<ImageModel> get unsavedPhotos => newestFirst
      .where((image) => image.isUploading == EUploadStatus.complete && !savedToPhotosIds.contains(image.id))
      .toList();

  int get unsavedCount => unsavedPhotos.length;

  /// The trip's photos ordered newest first, the order every gallery surface shows.
  List<ImageModel> get newestFirst => imageMap.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

enum EPhotoSavePhase {
  saving,
  done,

  /// The user declined photo library access, so nothing was saved.
  denied,
}

/// Snapshot of a "Save to Photos" run over the trip gallery.
@freezed
abstract class PhotoSaveProgress with _$PhotoSaveProgress {
  const factory PhotoSaveProgress({
    required EPhotoSavePhase phase,

    /// Photos this run set out to save (already-saved ones are excluded).
    @Default(0) int total,
    @Default(0) int saved,
    @Default(0) int failed,

    /// The Photos album this run saves into; `null` when photos are saved loose
    /// in the library (add-only access).
    String? album,
  }) = _PhotoSaveProgress;
}
