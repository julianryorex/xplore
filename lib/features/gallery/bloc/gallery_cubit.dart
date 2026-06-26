import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/features/gallery/services/image_compressor.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/gallery/bloc/gallery_cubit.freezed.dart';
part 'gallery_states.dart';

// TODOs:
// - Keep `itineraryId` as the late-subscriber/demo fallback until trip switching
//   can replay or synchronously expose the active trip id.
// - Support selection & compression w/ video
// - Implement GCP fetches/downloads after fetching cache
class GalleryCubit extends Cubit<GalleryState> with TripStreamMixin {
  late final Logger _logger;
  late final GalleryRepository repository;
  final AuthService _authService;
  StreamSubscription<TripState>? _tripSubscription;
  String? _activeTripId;

  GalleryCubit(this._authService, {GalleryRepository? repo}) : super(const GalleryState()) {
    repository = repo ?? GalleryRepository();
    _logger = createLogger('Gallery');
    _tripSubscription = listenToTripState(_onTripStateChanged);

    loadImgFromCache();
  }

  /// The uploader's Firebase UID, or null when unauthenticated.
  String? get _uid => _authService.currentUid;

  String get _tripScopeId => _activeTripId ?? itineraryId;

  void loadImgFromCache() {
    _logger.d('Load cached gallery');
    emit(state.copyWith(status: EBlocStatus.loading));

    repository.loadImgFromCache().then((images) {
      emit(state.copyWith(imageMap: images, status: EBlocStatus.loaded));
      _logger.d('Loaded gallery in state from Hive');
    });
  }

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  /// Uploads user selected photo gallery images to GCP.
  /// Each image goes through the following process:
  /// 1. Convert Xfile (image) to file,
  /// 2. Generate a downscaled/compressed thumbnail (`lowResImage`) for fast
  ///    local display — the full-resolution original is left untouched.
  /// 3. Convert file to `ImageModel` (w/ thumbnail)
  /// 4. Save to state
  /// 5. Cache in Hive
  /// 6. Cache high-res image in Hive
  /// 7. Upload high-res image to GCP
  Future<void> uploadToGallery() async {
    final picker = ImagePicker();
    final pickedImagesFuture = picker.pickMultiImage();
    await Future.delayed(const Duration(milliseconds: 200));

    emit(state.copyWith(status: EBlocStatus.loading));
    final pickedImages = await pickedImagesFuture;

    // TODO: support compression w/ video
    // final pickedImages = await picker.pickMultipleMedia();

    if (pickedImages.isEmpty) {
      emit(state.copyWith(status: EBlocStatus.loaded));
      return;
    }

    for (int i = 0; i < pickedImages.length; i++) {
      final image = pickedImages[i];

      // start cloud upload of pictures
      final file = _xFileToFile(image);
      if (file == null) {
        _logger.w('File is null, skipping iteration');
        continue;
      }

      // Build the lightweight thumbnail (`lowResImage`) for fast local display
      // using the pure-Dart `image` package (no native plugin / iOS SDK risk).
      // The full-resolution original (`file`) is preserved for the Hive
      // high-res cache and the Storage upload below, so other members still see
      // the full-detail photo.
      final originalBytes = await file.readAsBytes();
      final thumbnail = await compressGalleryThumbnailAsync(originalBytes);

      final imageModel = ImageModel(
        id: const Uuid().v4(),
        createdAt: await image.lastModified(),
        isUploading: EUploadStatus.uploading,
        lowResImage: thumbnail,
      );

      _addMapItemToState(imageModel); // save to state
      await repository.cacheMetadata(imageModel); // cache imageModel meta + lowres in Hive
      repository.cacheHighResImage(imageModel.id, file); // cache imageModel high res in Hive

      // Upload image to google cloud and update image loading status for the UI
      uploadImage(file, imageModel.id)
          .then((downloadUrl) {
            _logger.d('Image Uploaded');
            final newMapItem = state.imageMap[imageModel.id]!.copyWith(
              isUploading: EUploadStatus.complete, // set upload as finished
              downloadUrl: downloadUrl,
            );
            repository.cacheMetadata(newMapItem);
            _addMapItemToState(newMapItem);
          })
          .onError((err, _) {
            _logger.w('Error uploading image ${image.name}: $err');
            final newMapItem = state.imageMap[imageModel.id]!.copyWith(
              isUploading: EUploadStatus.failed, // set upload as failed
            );
            repository.cacheMetadata(newMapItem);
            _addMapItemToState(newMapItem);
          });
    }

    _logger.d('Upload started');
    emit(state.copyWith(status: EBlocStatus.loaded));
  }

  Future<Uint8List> fetchHighResAsset(String id) async {
    final watch = Stopwatch()..start();
    final box = await Hive.openBox('gallery-res');
    final Uint8List currentImgBytes = await box.get(id);
    watch.stop();
    _logger.d('Hive fetch took ${watch.elapsedMilliseconds}ms');
    return currentImgBytes;
  }

  //! -------------------------------------------------------------------------
  //! Helpers
  //! -------------------------------------------------------------------------

  void _addMapItemToState(ImageModel imageModelToAdd) {
    final newMap = {...state.imageMap, imageModelToAdd.id: imageModelToAdd};
    emit(state.copyWith(imageMap: newMap));
  }

  void _onTripStateChanged(TripState tripState) {
    switch (tripState) {
      case TripLoaded(:final active):
        _activeTripId = active.id;
      case TripEmpty() || TripError():
        _activeTripId = null;
      case TripLoading():
        break;
    }
  }

  /// Converts image file to more generic file
  File? _xFileToFile(XFile xFile) {
    try {
      File file = File(xFile.path);
      return file;
    } catch (e) {
      _logger.d('Error converting XFile to File: $e');
      return null;
    }
  }

  @visibleForTesting
  Future<String> uploadImage(File imageFile, String imageName) async {
    final uid = _uid;
    if (uid == null) {
      return Future.error(StateError('Cannot upload to gallery while unauthenticated.'));
    }

    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('gallery/$_tripScopeId/$uid/$imageName');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Deletes all gallery metadata & high resolution images
  ///
  /// Only use for testing
  Future<void> deleteAll() async {
    await repository.reset();
    emit(const GalleryState(status: EBlocStatus.loaded));
  }

  @override
  Future<void> close() async {
    await _tripSubscription?.cancel();
    return super.close();
  }
}
