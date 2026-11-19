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
import 'package:xplore/features/gallery/services/photo_content_hash.dart';
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
///
/// Every operation captures the trip it started on and carries that id through
/// its awaits. Work that finishes after the user switched trips still writes to
/// the caches of the trip it belongs to, but never into the visible state.
class GalleryCubit extends Cubit<GalleryState> with TripStreamMixin {
  final Logger _logger = createLogger('Gallery');
  final GalleryRepository repository;
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

  // A flag rather than the emitted phase: the phase is only emitted after the
  // permission prompt, which would let a second tap start a parallel run.
  bool _isSavingAll = false;
  Timer? _saveResultTimer;
  Timer? _duplicatesNoticeTimer;
  Timer? _firstSyncTimer;

  /// How long an empty album is presented as "still syncing" before it is
  /// shown as it is; the listener can stay silent on a bad connection.
  static const _firstSyncPatience = Duration(seconds: 8);

  /// Firestore rejects longer names, which would make every upload by that member fail.
  static const _maxUploaderNameLength = 40;

  GalleryCubit(this._authService, {GalleryRepository? repo, this._service, this._photoSaver})
    : repository = repo ?? GalleryRepository(),
      super(const GalleryState()) {
    // This cubit is created lazily, after Home has shown the trip, so the state
    // that announced the trip has usually been pushed already.
    _tripSubscription = listenToTripState(_onTripStateChanged, replayLatest: true);
  }

  GalleryService get _galleryService => _service ??= GalleryService();
  PhotoSaveService get _photoSaveService => _photoSaver ??= GalPhotoSaveService();

  /// The signed-in member's Firebase UID (null when unauthenticated), for telling own photos from others'.
  String? get currentUid => _authService.currentUid;

  /// First name only: it is shown to every trip member next to the photo.
  String? get _uploaderName {
    final firstName = (_authService.currentUser?.displayName ?? '').trim().split(RegExp(r'\s+')).first;
    if (firstName.isEmpty) return null;
    return String.fromCharCodes(firstName.runes.take(_maxUploaderNameLength));
  }

  bool _isActive(String? tripId) => !isClosed && tripId == _activeTripId;

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  /// Lets the user pick photos and adds them to the trip gallery.
  Future<void> uploadToGallery() async {
    // Captured before the picker opens: the photos belong to the trip the user was looking at.
    final tripId = _activeTripId;
    if (tripId == null) return;

    await addPhotos(tripId, await ImagePicker().pickMultiImage());
  }

  /// Adds [photos] to [tripId]'s gallery. Each appears immediately from a local
  /// thumbnail while its full-resolution original uploads in the background.
  /// Photos the trip already has (same file contents) are skipped.
  @visibleForTesting
  Future<void> addPhotos(String tripId, List<XFile> photos) async {
    // One pass over the album per pick; each photo is then a constant-time lookup.
    final knownHashes = await _contentHashes(tripId);
    var duplicates = 0;

    for (final photo in photos) {
      try {
        final added = await _addLocalPhoto(tripId, File(photo.path), knownHashes);
        if (!added) duplicates++;
      } catch (err) {
        _logger.w('Could not add ${photo.name} to the gallery: $err');
      }
    }

    if (duplicates > 0 && _isActive(tripId)) _showDuplicatesNotice(duplicates);
  }

  /// The full-resolution original of photo [id] as a local file, downloading
  /// and caching it when it is not on this device yet. `null` if unavailable.
  Future<File?> fetchFullResFile(String id) async {
    final tripId = _activeTripId;
    final image = state.imageMap[id];
    if (tripId == null || image == null) return null;

    try {
      return await _fullResFile(tripId, image);
    } catch (err) {
      _logger.w('Could not load full-resolution photo $id: $err');
      return null;
    }
  }

  /// Re-attempts the upload of a photo whose status is [EUploadStatus.failed].
  Future<void> retryUpload(String id) async {
    final tripId = _activeTripId;
    final image = state.imageMap[id];
    if (tripId == null || image == null || image.isUploading != EUploadStatus.failed) return;

    final retrying = image.copyWith(isUploading: EUploadStatus.uploading);
    await _storeImage(tripId, retrying);
    await _upload(tripId, retrying);
  }

  /// Retries every photo whose upload failed.
  Future<void> retryFailedUploads() async {
    final failedIds = state.imageMap.values
        .where((image) => image.isUploading == EUploadStatus.failed)
        .map((image) => image.id)
        .toList();
    await Future.wait(failedIds.map(retryUpload));
  }

  /// Saves every trip photo not yet saved from this device into the trip's
  /// album in the Photos app, reporting progress through [GalleryState.saveProgress].
  Future<void> saveAllToPhotos() async {
    final tripId = _activeTripId;
    if (tripId == null || _isSavingAll) return;

    _isSavingAll = true;
    try {
      final access = await _photoSaveService.requestAccess();
      // The prompt can stay up for a while; the result belongs to the trip it was asked for.
      if (!_isActive(tripId)) return;

      _saveResultTimer?.cancel();
      if (access == EPhotoLibraryAccess.denied) {
        emit(state.copyWith(saveProgress: const PhotoSaveProgress(phase: EPhotoSavePhase.denied)));
        return;
      }

      final album = _albumFor(access);
      final pending = state.unsavedPhotos;
      var progress = PhotoSaveProgress(phase: EPhotoSavePhase.saving, total: pending.length, album: album);
      emit(state.copyWith(saveProgress: progress));

      for (final image in pending) {
        final saved = await _saveToPhotos(tripId, image, album: album);
        if (!_isActive(tripId)) return;

        progress = saved
            ? progress.copyWith(saved: progress.saved + 1)
            : progress.copyWith(failed: progress.failed + 1);
        emit(state.copyWith(saveProgress: progress));
      }

      emit(state.copyWith(saveProgress: progress.copyWith(phase: EPhotoSavePhase.done)));
      _scheduleSaveResultDismissal(hadFailures: progress.failed > 0);
    } finally {
      _isSavingAll = false;
    }
  }

  /// Saves the single photo [id] to the Photos app; returns whether it was saved.
  Future<bool> savePhotoToPhotos(String id) async {
    final tripId = _activeTripId;
    final image = state.imageMap[id];
    if (tripId == null || image == null) return false;

    final access = await _photoSaveService.requestAccess();
    if (access == EPhotoLibraryAccess.denied) return false;

    return _saveToPhotos(tripId, image, album: _albumFor(access));
  }

  /// Opens the Photos app, where the trip album lives.
  Future<void> openPhotosApp() => _photoSaveService.openPhotosApp();

  /// Clears [GalleryState.saveProgress] once the UI has shown it.
  void dismissSaveProgress() {
    _saveResultTimer?.cancel();
    emit(state.copyWith(saveProgress: null));
  }

  /// Uploads [imageFile] to [storagePath] in Firebase Storage and returns its download URL.
  @visibleForTesting
  Future<String> uploadImage(File imageFile, String storagePath) async {
    final snapshot = await FirebaseStorage.instance.ref().child(storagePath).putFile(imageFile);
    return snapshot.ref.getDownloadURL();
  }

  /// Deletes the active trip's cached gallery from this device. Dev tools only.
  Future<void> deleteAll() async {
    final tripId = _activeTripId;
    if (tripId == null) return;

    await repository.reset(tripId);
    if (_isActive(tripId)) emit(const GalleryState(status: EBlocStatus.loaded, hasSyncedWithCloud: true));
  }

  @override
  Future<void> close() async {
    _saveResultTimer?.cancel();
    _duplicatesNoticeTimer?.cancel();
    _firstSyncTimer?.cancel();
    await _tripSubscription?.cancel();
    await _remoteSubscription?.cancel();
    return super.close();
  }

  //! -------------------------------------------------------------------------
  //! Uploading
  //! -------------------------------------------------------------------------

  /// Returns false when the trip already has this exact file, in which case nothing is added.
  Future<bool> _addLocalPhoto(String tripId, File pickedFile, Set<String> knownHashes) async {
    final originalBytes = await pickedFile.readAsBytes();
    final contentHash = await photoContentHashAsync(originalBytes);
    // `add` also catches the same photo picked twice in one go.
    if (!knownHashes.add(contentHash)) return false;

    final image = ImageModel(
      id: const Uuid().v4(),
      // The file's own dates are when it was picked, which would file every photo under its upload day.
      createdAt: readPhotoTakenAt(originalBytes) ?? await pickedFile.lastModified(),
      isUploading: EUploadStatus.uploading,
      lowResImage: await compressGalleryThumbnailAsync(originalBytes),
      uploaderUid: currentUid,
      uploaderName: _uploaderName,
      contentHash: contentHash,
    );

    // Copy the original before the photo becomes visible: the picker's file is
    // temporary, and a photo without a cached original could never upload or be retried.
    await repository.cacheFullRes(tripId, image.id, pickedFile);
    await _storeImage(tripId, image);
    unawaited(_upload(tripId, image));
    return true;
  }

  /// Content hashes of every photo [tripId] is known to have on this device.
  Future<Set<String>> _contentHashes(String tripId) async {
    // The visible state includes other members' photos from the live listener;
    // a trip that is not on screen only has what was cached.
    final images = _isActive(tripId) ? state.imageMap.values : (await repository.loadImgFromCache(tripId)).values;
    return {for (final image in images) ?image.contentHash};
  }

  void _showDuplicatesNotice(int duplicates) {
    _duplicatesNoticeTimer?.cancel();
    emit(state.copyWith(duplicatesSkipped: duplicates));
    _duplicatesNoticeTimer = Timer(const Duration(seconds: 5), () {
      if (!isClosed) emit(state.copyWith(duplicatesSkipped: 0));
    });
  }

  /// Uploads the cached original of [image] and publishes its metadata doc so
  /// other members see it. Marks the photo failed on any error.
  Future<void> _upload(String tripId, ImageModel image) async {
    final id = image.id;
    _uploadsInFlight.add(id);
    try {
      final uid = currentUid;
      if (uid == null) throw StateError('Cannot upload to the gallery while signed out.');

      final file = await repository.fullResFile(tripId, id);
      if (file == null) throw StateError('The original of photo $id is no longer on this device.');

      // Null means the photo could not be decoded into a thumbnail small enough
      // for its metadata doc, so other members could never be shown it.
      final syncThumbnail = await compressGallerySyncThumbnailAsync(image.lowResImage);
      if (syncThumbnail == null) throw StateError('Photo $id has no usable thumbnail.');

      final storagePath = 'gallery/$tripId/$uid/$id';
      final downloadUrl = await uploadImage(file, storagePath);
      await _galleryService.writeImageMetadata(
        tripId: tripId,
        imageId: id,
        uploaderUid: uid,
        uploaderName: image.uploaderName,
        contentHash: image.contentHash,
        createdAt: image.createdAt,
        fullUrl: downloadUrl,
        storagePath: storagePath,
        thumb: syncThumbnail,
      );
      await _finishUpload(tripId, image, EUploadStatus.complete, downloadUrl: downloadUrl);
      await _releaseUploadedOriginal(tripId, id);
    } catch (err) {
      _logger.w('Error uploading photo $id: $err');
      await _finishUpload(tripId, image, EUploadStatus.failed);
    } finally {
      _uploadsInFlight.remove(id);
    }
  }

  /// Once the cloud holds the photo, the local original is only a re-downloadable
  /// cache. Failing to demote it must not turn a finished upload into a failed one.
  Future<void> _releaseUploadedOriginal(String tripId, String id) async {
    try {
      await repository.releaseUploadedOriginal(tripId, id);
    } catch (err) {
      _logger.w('Could not move the uploaded original of photo $id to the cache: $err');
    }
  }

  Future<void> _finishUpload(String tripId, ImageModel image, EUploadStatus status, {String? downloadUrl}) async {
    // Prefer the visible copy: the remote listener may already have updated it.
    final current = _isActive(tripId) ? state.imageMap[image.id] ?? image : image;
    await _storeImage(tripId, current.copyWith(isUploading: status, downloadUrl: downloadUrl ?? current.downloadUrl));
  }

  ImageModel _withInterruptedUploadFailed(ImageModel image) {
    final interrupted = image.isUploading == EUploadStatus.uploading && !_uploadsInFlight.contains(image.id);
    return interrupted ? image.copyWith(isUploading: EUploadStatus.failed) : image;
  }

  //! -------------------------------------------------------------------------
  //! Trip switching and cloud sync
  //! -------------------------------------------------------------------------

  void _onTripStateChanged(TripState tripState) {
    if (isClosed) return;
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
  /// memory, loads the new trip's cache and starts listening to its remote photos.
  void _switchTrip(String? tripId) {
    if (tripId == _activeTripId) return;
    final previousTripId = _activeTripId;
    // Frees the thumbnails Hive keeps in memory for a trip that is no longer on screen.
    if (previousTripId != null) unawaited(repository.closeTrip(previousTripId));
    _activeTripId = tripId;
    _saveResultTimer?.cancel();
    _duplicatesNoticeTimer?.cancel();
    _firstSyncTimer?.cancel();
    _remoteSubscription?.cancel();
    _remoteSubscription = null;

    if (tripId == null) {
      emit(const GalleryState());
      return;
    }

    emit(const GalleryState(status: EBlocStatus.loading));
    unawaited(_loadCachedPhotos(tripId));
    _firstSyncTimer = Timer(_firstSyncPatience, () {
      if (_isActive(tripId) && !state.hasSyncedWithCloud) emit(state.copyWith(hasSyncedWithCloud: true));
    });
    _remoteSubscription = _galleryService
        .watchTripImages(tripId)
        .listen(
          (remoteImages) => _onRemoteImages(tripId, remoteImages),
          onError: (Object err) {
            _logger.w('Gallery sync failed for trip $tripId: $err');
            // Stop presenting the album as "still syncing"; the cache is all there is for now.
            if (_isActive(tripId)) emit(state.copyWith(hasSyncedWithCloud: true));
          },
        );
  }

  Future<void> _loadCachedPhotos(String tripId) async {
    try {
      final cached = await repository.loadImgFromCache(tripId);
      final savedToPhotosIds = await repository.loadSavedPhotoIds(tripId);
      if (!_isActive(tripId)) return;

      final images = cached.map((id, image) => MapEntry(id, _withInterruptedUploadFailed(image)));
      // Merge rather than replace: a remote snapshot may have landed while Hive was loading.
      emit(
        state.copyWith(
          imageMap: {...images, ...state.imageMap},
          savedToPhotosIds: savedToPhotosIds,
          status: EBlocStatus.loaded,
        ),
      );
    } catch (err) {
      _logger.w('Could not load the cached gallery for trip $tripId: $err');
      if (_isActive(tripId)) emit(state.copyWith(status: EBlocStatus.loaded));
    }
  }

  /// Merges [tripId]'s remote photos into state by image id. A remote doc only
  /// exists once its upload fully succeeded, so it always marks the photo
  /// complete; a local copy keeps its sharper thumbnail.
  void _onRemoteImages(String tripId, List<ImageModel> remoteImages) {
    if (!_isActive(tripId)) return;

    final merged = {...state.imageMap};
    for (final remote in remoteImages) {
      final local = merged[remote.id];
      final next = local == null ? remote : remote.copyWith(lowResImage: local.lowResImage);
      if (next == local) continue;
      merged[remote.id] = next;
      unawaited(repository.cacheMetadata(tripId, next));
    }
    emit(state.copyWith(imageMap: merged, status: EBlocStatus.loaded, hasSyncedWithCloud: true));
  }

  //! -------------------------------------------------------------------------
  //! Helpers
  //! -------------------------------------------------------------------------

  /// Persists [image] under [tripId] and, when that trip is on screen, shows it.
  Future<void> _storeImage(String tripId, ImageModel image) async {
    if (_isActive(tripId)) emit(state.copyWith(imageMap: {...state.imageMap, image.id: image}));
    await repository.cacheMetadata(tripId, image);
  }

  Future<File?> _fullResFile(String tripId, ImageModel image) async {
    final cached = await repository.fullResFile(tripId, image.id);
    if (cached != null) return cached;

    final url = image.downloadUrl;
    return url == null ? null : repository.fetchAndCacheFullRes(tripId, image.id, url);
  }

  // Without album-level access photos can still be saved, just not grouped.
  String? _albumFor(EPhotoLibraryAccess access) =>
      access == EPhotoLibraryAccess.album ? tripAlbumName(_activeTripTitle) : null;

  Future<bool> _saveToPhotos(String tripId, ImageModel image, {String? album}) async {
    try {
      final file = await _fullResFile(tripId, image);
      if (file == null) return false;

      await _photoSaveService.saveImage(file, album: album);
      await repository.markPhotoSaved(tripId, image.id);
      if (_isActive(tripId)) emit(state.copyWith(savedToPhotosIds: {...state.savedToPhotosIds, image.id}));
      return true;
    } catch (err) {
      _logger.w('Could not save photo ${image.id} to Photos: $err');
      return false;
    }
  }

  /// A finished run is cleared here rather than by the page, which may no
  /// longer be on screen; failures stay up longer so they can be read.
  void _scheduleSaveResultDismissal({required bool hadFailures}) {
    _saveResultTimer?.cancel();
    _saveResultTimer = Timer(Duration(seconds: hadFailures ? 10 : 5), () {
      if (!isClosed && state.saveProgress?.phase == EPhotoSavePhase.done) {
        emit(state.copyWith(saveProgress: null));
      }
    });
  }
}
