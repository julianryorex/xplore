import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/gallery/bloc/gallery_cubit.freezed.dart';
part 'gallery_states.dart';

// TODOs:
// - Fetch current itinerary id from another cubit or Hive
// - Support selection & compression w/ video
// - Implement GCP fetches/downloads after fetching cache
class GalleryCubit extends Cubit<GalleryState> {
  late final Logger _logger;
  late final GalleryRepository repository;

  GalleryCubit({GalleryRepository? repo}) : super(const GalleryState()) {
    repository = repo ?? GalleryRepository();
    _logger = createLogger('Gallery');

    loadImgFromCache();
  }

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
  /// 2. Compress image by 50%
  /// 3. Convert file to `ImageModel` (w/ compressed)
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

      // TODO: re-enable compression once flutter_image_compress supports the
      // iOS 26 SDK. The dependency is temporarily disabled (see pubspec.yaml),
      // so we fall back to the original, uncompressed image bytes for now.
      final compressedImage = await file.readAsBytes();

      final imageModel = ImageModel(
        id: const Uuid().v4(),
        createdAt: await image.lastModified(),
        isUploading: EUploadStatus.uploading,
        lowResImage: compressedImage,
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

  // TODO: Fetch current itinerary id
  @visibleForTesting
  Future<String> uploadImage(File imageFile, String imageName) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('gallery/ph4kd/$imageName');
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
}
