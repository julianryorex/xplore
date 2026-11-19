import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/features/gallery/services/gallery_service.dart';
import 'package:xplore/features/gallery/services/image_compressor.dart';
import 'package:xplore/features/gallery/services/photo_save_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/gallery/bloc/gallery_cubit.freezed.dart';
part 'gallery_states.dart';

/// Owns the active trip's shared photo gallery.
///
/// Local photos are shown optimistically from the Hive cache while they upload;
/// every member's photos arrive through a live Firestore listener and are merged
/// in by image id. Full-resolution originals live as files and load on demand.
class GalleryCubit extends Cubit<GalleryState> with TripStreamMixin {
  late final Logger _logger;
  late final GalleryRepository repository;
  final AuthService _authService;

  // Created on first use so the cubit can be built without Firebase or the
  // photo plugin (unit tests, and before a trip is active).
  GalleryService? _service;
  PhotoSaveService? _photoSaver;

  StreamSubscription<TripState>? _tripSubscription;
  StreamSubscription<List<ImageModel>>? _remoteSubscription;
  String? _activeTripId;
  String _activeTripTitle = '';

  /// Ids whose upload is running in this session. Anything else cached as
  /// `uploading` was interrupted (app killed mid-upload) and needs a retry.
  final Set<String> _uploadsInFlight = {};

  GalleryCubit(this._authService, {GalleryRepository? repo, this._service, this._photoSaver})
    : super(const GalleryState()) {
    repository = repo ?? GalleryRepository();
    _logger = createLogger('Gallery');
    _tripSubscription = listenToTripState(_onTripStateChanged);

    loadImgFromCache();
  }

  GalleryService get _galleryService => _service ??= GalleryService();
  PhotoSaveService get _photoSaveService => _photoSaver ??= GalPhotoSaveService();

  /// The signed-in member's Firebase UID (null when unauthenticated), for telling own photos from others'.
  String? get currentUid => _authService.currentUid;

  String? get _uid => currentUid;

  /// First name only: it is shown to every trip member next to the photo.
  String? get _uploaderName {
    final firstName = (_authService.currentUser?.displayName ?? '').trim().split(RegExp(r'\s+')).first;
    return firstName.isEmpty ? null : firstName;
  }

  /// Loads the active trip's cached photos into state.
  Future<void> loadImgFromCache() async {
    final tripId = _activeTripId;
    emit(state.copyWith(status: EBlocStatus.loading));

    final cached = await repository.loadImgFromCache();
    final savedToPhotosIds = await repository.loadSavedPhotoIds();
    if (isClosed || tripId != _activeTripId) return;

    final images = cached.map((id, image) => MapEntry(id, _withInterruptedUploadFailed(image)));
    // Merge rather than replace: a remote snapshot may have landed while Hive was loading.
    emit(
      state.copyWith(
        imageMap: {...images, ...state.imageMap},
        savedToPhotosIds: savedToPhotosIds,
        status: EBlocStatus.loaded,
      ),
    );
  }

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  /// Lets the user pick photos and adds them to the trip gallery. Each photo
  /// appears immediately from a local thumbnail while its full-resolution
  /// original uploads in the background.
  Future<void> uploadToGallery() async {
    final pickedImages = await ImagePicker().pickMultiImage();

    for (final image in pickedImages) {
      try {
        await _addLocalPhoto(File(image.path), await image.lastModified());
      } catch (err) {
        _logger.w('Could not add ${image.name} to the gallery: $err');
      }
    }
  }

  /// The full-resolution original of photo [id] as a local file, downloading
  /// and caching it when it is not on this device yet. `null` if unavailable.
  Future<File?> fetchFullResFile(String id) async {
    try {
      final cached = await repository.fullResFile(id);
      if (cached != null) return cached;

      final url = state.imageMap[id]?.downloadUrl;
      return url == null ? null : await repository.fetchAndCacheFullRes(id, url);
    } catch (err) {
      _logger.w('Could not load full-resolution photo $id: $err');
      return null;
    }
  }

  /// Re-attempts the upload of a photo whose status is [EUploadStatus.failed].
  Future<void> retryUpload(String id) async {
    final image = state.imageMap[id];
    if (image == null || image.isUploading != EUploadStatus.failed) return;

    await _storeImage(image.copyWith(isUploading: EUploadStatus.uploading));
    await _upload(id);
  }

  /// Saves every trip photo not yet saved from this device into the trip's
  /// album in the Photos app, reporting progress through [GalleryState.saveProgress].
  Future<void> saveAllToPhotos() async {
    if (state.saveProgress?.phase == EPhotoSavePhase.saving) return;
    final tripId = _activeTripId;
    if (tripId == null) return;

    final access = await _photoSaveService.requestAccess();
    if (access == EPhotoLibraryAccess.denied) {
      emit(state.copyWith(saveProgress: const PhotoSaveProgress(phase: EPhotoSavePhase.denied)));
      return;
    }
    // Without album-level access photos can still be saved, just not grouped.
    final album = access == EPhotoLibraryAccess.album ? tripAlbumName(_activeTripTitle) : null;

    final pending = state.newestFirst
        .where((image) => image.isUploading == EUploadStatus.complete && !state.savedToPhotosIds.contains(image.id))
        .toList();

    var progress = PhotoSaveProgress(phase: EPhotoSavePhase.saving, total: pending.length, album: album);
    emit(state.copyWith(saveProgress: progress));

    for (final image in pending) {
      // The saved-ids record and album belong to the trip the run started on.
      if (isClosed || tripId != _activeTripId) return;

      final saved = await _saveToPhotos(image.id, album: album);
      progress = saved ? progress.copyWith(saved: progress.saved + 1) : progress.copyWith(failed: progress.failed + 1);
      if (isClosed || tripId != _activeTripId) return;
      emit(state.copyWith(saveProgress: progress));
    }

    emit(state.copyWith(saveProgress: progress.copyWith(phase: EPhotoSavePhase.done)));
  }

  /// Saves the single photo [id] to the Photos app; returns whether it was saved.
  Future<bool> savePhotoToPhotos(String id) async {
    final access = await _photoSaveService.requestAccess();
    if (access == EPhotoLibraryAccess.denied) return false;

    final album = access == EPhotoLibraryAccess.album ? tripAlbumName(_activeTripTitle) : null;
    return _saveToPhotos(id, album: album);
  }

  /// Opens the Photos app, where the trip album lives.
  Future<void> openPhotosApp() => _photoSaveService.openPhotosApp();

  /// Retries every photo whose upload failed.
  Future<void> retryFailedUploads() async {
    final failedIds = state.imageMap.values
        .where((image) => image.isUploading == EUploadStatus.failed)
        .map((image) => image.id)
        .toList();
    await Future.wait(failedIds.map(retryUpload));
  }

  /// Clears a finished [GalleryState.saveProgress] once the UI has shown it.
  void dismissSaveProgress() => emit(state.copyWith(saveProgress: null));

  /// Uploads [imageFile] to the active trip's Storage prefix and returns its download URL.
  @visibleForTesting
  Future<String> uploadImage(File imageFile, String imageName) async {
    final path = _storagePath(imageName);
    final snapshot = await FirebaseStorage.instance.ref().child(path).putFile(imageFile);
    return snapshot.ref.getDownloadURL();
  }

  /// Deletes all gallery metadata & high-resolution images
  ///
  /// Only use for testing
  Future<void> deleteAll() async {
    await repository.reset();
    emit(const GalleryState(status: EBlocStatus.loaded));
  }

  @override
  Future<void> close() async {
    await _tripSubscription?.cancel();
    await _remoteSubscription?.cancel();
    return super.close();
  }

  //! -------------------------------------------------------------------------
  //! Uploading
  //! -------------------------------------------------------------------------

  Future<void> _addLocalPhoto(File pickedFile, DateTime createdAt) async {
    final thumbnail = await compressGalleryThumbnailAsync(await pickedFile.readAsBytes());
    final image = ImageModel(
      id: const Uuid().v4(),
      createdAt: createdAt,
      isUploading: EUploadStatus.uploading,
      lowResImage: thumbnail,
      uploaderUid: _uid,
      uploaderName: _uploaderName,
    );

    await _storeImage(image);
    // The picker's file is temporary; the cached copy is what uploads, retries and the viewer read.
    await repository.cacheFullRes(image.id, pickedFile);
    unawaited(_upload(image.id));
  }

  /// Uploads the cached original of photo [id] and publishes its metadata doc
  /// so other members see it. Marks the photo failed on any error.
  Future<void> _upload(String id) async {
    final tripId = _activeTripId;
    _uploadsInFlight.add(id);
    try {
      final file = await repository.fullResFile(id);
      final image = state.imageMap[id];
      final uid = _uid;
      if (file == null || image == null || uid == null || tripId == null) {
        throw StateError('Photo $id cannot be uploaded right now.');
      }

      final storagePath = _storagePath(id);
      // Null means the photo could not be decoded into a thumbnail small enough
      // for its metadata doc, so other members could never be shown it.
      final syncThumbnail = await compressGallerySyncThumbnailAsync(image.lowResImage);
      if (syncThumbnail == null) throw StateError('Photo $id has no usable thumbnail.');

      final downloadUrl = await uploadImage(file, id);
      await _galleryService.writeImageMetadata(
        tripId: tripId,
        imageId: id,
        uploaderUid: uid,
        uploaderName: image.uploaderName,
        createdAt: image.createdAt,
        fullUrl: downloadUrl,
        storagePath: storagePath,
        thumb: syncThumbnail,
      );
      await _finishUpload(id, tripId, EUploadStatus.complete, downloadUrl: downloadUrl);
    } catch (err) {
      _logger.w('Error uploading photo $id: $err');
      await _finishUpload(id, tripId, EUploadStatus.failed);
    } finally {
      _uploadsInFlight.remove(id);
    }
  }

  Future<void> _finishUpload(String id, String? tripId, EUploadStatus status, {String? downloadUrl}) async {
    // State and the Hive cache are scoped to the active trip; if the user moved
    // on, the remote listener reconciles this photo when they come back.
    final image = state.imageMap[id];
    if (isClosed || tripId != _activeTripId || image == null) return;
    await _storeImage(image.copyWith(isUploading: status, downloadUrl: downloadUrl ?? image.downloadUrl));
  }

  String _storagePath(String imageId) {
    final uid = _uid;
    if (uid == null) throw StateError('Cannot upload to gallery while unauthenticated.');
    final tripId = _activeTripId;
    if (tripId == null) throw StateError('Cannot upload to gallery without an active trip.');
    return 'gallery/$tripId/$uid/$imageId';
  }

  ImageModel _withInterruptedUploadFailed(ImageModel image) {
    final interrupted = image.isUploading == EUploadStatus.uploading && !_uploadsInFlight.contains(image.id);
    return interrupted ? image.copyWith(isUploading: EUploadStatus.failed) : image;
  }

  //! -------------------------------------------------------------------------
  //! Cloud sync
  //! -------------------------------------------------------------------------

  /// Merges the trip's remote photos into state by image id. A remote doc only
  /// exists once its upload fully succeeded, so it always marks the photo
  /// complete; a local copy keeps its sharper thumbnail.
  void _onRemoteImages(List<ImageModel> remoteImages) {
    final merged = {...state.imageMap};
    for (final remote in remoteImages) {
      final local = merged[remote.id];
      final next = local == null ? remote : remote.copyWith(lowResImage: local.lowResImage);
      if (next == local) continue;
      merged[remote.id] = next;
      unawaited(repository.cacheMetadata(next));
    }
    emit(state.copyWith(imageMap: merged, status: EBlocStatus.loaded));
  }

  void _onTripStateChanged(TripState tripState) {
    switch (tripState) {
      case TripLoaded(:final active):
        _activeTripTitle = active.title;
        _switchTrip(active.id);
      case TripEmpty() || TripError():
        _switchTrip(null);
      case TripLoading():
        break;
    }
  }

  /// Points the gallery at [tripId]: drops the previous trip's photos from
  /// memory, reloads the new trip's cache and starts listening to its remote photos.
  void _switchTrip(String? tripId) {
    if (tripId == _activeTripId) return;
    _activeTripId = tripId;
    repository.setTrip(tripId);
    _remoteSubscription?.cancel();
    _remoteSubscription = null;
    emit(const GalleryState(status: EBlocStatus.loading));
    loadImgFromCache();

    if (tripId == null) return;
    _remoteSubscription = _galleryService
        .watchTripImages(tripId)
        .listen(_onRemoteImages, onError: (Object err) => _logger.w('Gallery sync failed for trip $tripId: $err'));
  }

  //! -------------------------------------------------------------------------
  //! Helpers
  //! -------------------------------------------------------------------------

  Future<void> _storeImage(ImageModel image) async {
    emit(state.copyWith(imageMap: {...state.imageMap, image.id: image}));
    await repository.cacheMetadata(image);
  }

  Future<bool> _saveToPhotos(String id, {String? album}) async {
    try {
      final file = await fetchFullResFile(id);
      if (file == null) return false;
      await _photoSaveService.saveImage(file, album: album);
      await repository.markPhotoSaved(id);
      if (!isClosed) emit(state.copyWith(savedToPhotosIds: {...state.savedToPhotosIds, id}));
      return true;
    } catch (err) {
      _logger.w('Could not save photo $id to Photos: $err');
      return false;
    }
  }
}
