import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/features/gallery/services/gallery_service.dart';
import 'package:xplore/features/gallery/services/photo_save_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

import '../../helpers/auth_fixtures.dart';

/// Repository that skips Hive so the cubit can be constructed in a unit test.
class _EmptyGalleryRepository extends GalleryRepository {
  @override
  Future<Map<String, ImageModel>> loadImgFromCache() async => {};
}

/// In-memory stand-in for the Hive + file cache.
class _FakeGalleryRepository extends GalleryRepository {
  _FakeGalleryRepository({Map<String, ImageModel>? cached}) : metadata = {...?cached};

  final Map<String, ImageModel> metadata;
  final Set<String> savedToPhotos = {};

  /// Ids whose full-resolution original is "on disk".
  final Set<String> fullRes = {};

  @override
  void setTrip(String? tripId) {}

  @override
  Future<Map<String, ImageModel>> loadImgFromCache() async => {...metadata};

  @override
  Future<void> cacheMetadata(ImageModel imageModel) async => metadata[imageModel.id] = imageModel;

  @override
  Future<File?> fullResFile(String id) async => fullRes.contains(id) ? File('$id.jpg') : null;

  @override
  Future<File?> fetchAndCacheFullRes(String id, String url) async {
    if (url.contains('broken')) throw const HttpException('Download failed');
    return File('$id.jpg');
  }

  @override
  Future<Set<String>> loadSavedPhotoIds() async => {...savedToPhotos};

  @override
  Future<void> markPhotoSaved(String id) async => savedToPhotos.add(id);
}

class _FakeGalleryService implements GalleryService {
  final remoteImages = StreamController<List<ImageModel>>.broadcast();
  final List<String> writtenImageIds = [];

  @override
  Stream<List<ImageModel>> watchTripImages(String tripId) => remoteImages.stream;

  @override
  Future<void> writeImageMetadata({
    required String tripId,
    required String imageId,
    required String uploaderUid,
    required DateTime createdAt,
    required String fullUrl,
    required String storagePath,
    required Uint8List thumb,
    String? uploaderName,
  }) async => writtenImageIds.add(imageId);
}

class _FakePhotoSaveService implements PhotoSaveService {
  _FakePhotoSaveService(this.access);

  final EPhotoLibraryAccess access;
  final Map<String, String?> albumBySavedPath = {};

  @override
  Future<EPhotoLibraryAccess> requestAccess() async => access;

  @override
  Future<void> saveImage(File file, {String? album}) async => albumBySavedPath[file.path] = album;

  @override
  Future<void> openPhotosApp() async {}
}

/// Cubit whose Storage upload is replaced, so the rest of the upload flow runs for real.
class _OfflineStorageGalleryCubit extends GalleryCubit {
  _OfflineStorageGalleryCubit(super.authService, {super.repo, super.service, super.photoSaver});

  @override
  Future<String> uploadImage(File imageFile, String imageName) async => 'https://storage.test/$imageName';
}

const _trip = TripModel(id: 'trip-1', title: 'Lisbon', memberIds: ['me'], createdBy: 'me');

final Uint8List _jpeg = img.encodeJpg(img.Image(width: 8, height: 8));

ImageModel _image(String id, {EUploadStatus status = EUploadStatus.complete, String? url, Uint8List? thumbnail}) {
  return ImageModel(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    lowResImage: thumbnail ?? _jpeg,
    isUploading: status,
    downloadUrl: url ?? (status == EUploadStatus.complete ? 'https://storage.test/$id' : null),
  );
}

/// Lets the cubit's un-awaited async work (cache load, listener, uploads) settle.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GalleryCubit.uploadImage', () {
    // FEAT-004: the uploader path is uid-scoped, so an unauthenticated upload
    // must fail fast rather than fall back to a hardcoded id.
    test('errors out when the user is not authenticated', () async {
      final cubit = GalleryCubit(fakeAuthService(signedIn: false), repo: _EmptyGalleryRepository());

      await expectLater(cubit.uploadImage(File('unused.jpg'), 'image-1'), throwsA(isA<StateError>()));

      await cubit.close();
    });

    // FEAT-014: uploads are strictly trip-scoped (gallery/{tripId}/{uid}/...),
    // so with no active trip the upload must fail fast instead of falling back
    // to the removed `ph4kd` demo id.
    test('errors out when there is no active trip', () async {
      final cubit = GalleryCubit(fakeAuthService(signedIn: true), repo: _EmptyGalleryRepository());

      await expectLater(cubit.uploadImage(File('unused.jpg'), 'image-1'), throwsA(isA<StateError>()));

      await cubit.close();
    });
  });

  group('GalleryCubit on an active trip', () {
    late _FakeGalleryService service;

    Future<GalleryCubit> openTrip(_FakeGalleryRepository repo, {PhotoSaveService? photoSaver}) async {
      service = _FakeGalleryService();
      final cubit = _OfflineStorageGalleryCubit(
        fakeAuthService(signedIn: true, user: MockUser(uid: 'me')),
        repo: repo,
        service: service,
        photoSaver: photoSaver,
      );
      cubit.pushTripEvent(const TripState.loaded(active: _trip, all: [_trip]));
      await _settle();
      return cubit;
    }

    test('merges remote photos: adds other members\' and completes our own, keeping the local thumbnail', () async {
      final localThumbnail = Uint8List.fromList([1, 2, 3]);
      final repo = _FakeGalleryRepository(
        cached: {'mine': _image('mine', status: EUploadStatus.failed, thumbnail: localThumbnail)},
      );
      final cubit = await openTrip(repo);

      service.remoteImages.add([_image('mine'), _image('theirs')]);
      await _settle();

      final images = cubit.state.imageMap;
      expect(images.keys, unorderedEquals(['mine', 'theirs']));
      expect(images['mine']!.isUploading, EUploadStatus.complete);
      expect(images['mine']!.downloadUrl, isNotNull);
      expect(images['mine']!.lowResImage, localThumbnail);
      // Remote photos are cached so the gallery is populated offline next launch.
      expect(repo.metadata.keys, containsAll(['mine', 'theirs']));

      await cubit.close();
    });

    test('an upload interrupted by an app restart is shown as failed so it can be retried', () async {
      final repo = _FakeGalleryRepository(cached: {'stuck': _image('stuck', status: EUploadStatus.uploading)});
      final cubit = await openTrip(repo);

      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.failed);

      await cubit.close();
    });

    test('retryUpload re-uploads from the cached original and publishes the photo', () async {
      final repo = _FakeGalleryRepository(cached: {'stuck': _image('stuck', status: EUploadStatus.failed)})
        ..fullRes.add('stuck');
      final cubit = await openTrip(repo);

      await cubit.retryUpload('stuck');

      expect(service.writtenImageIds, ['stuck']);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.complete);
      expect(repo.metadata['stuck']!.downloadUrl, 'https://storage.test/stuck');

      await cubit.close();
    });

    test('retryUpload keeps the photo failed when its original is gone', () async {
      final repo = _FakeGalleryRepository(cached: {'stuck': _image('stuck', status: EUploadStatus.failed)});
      final cubit = await openTrip(repo);

      await cubit.retryUpload('stuck');

      expect(service.writtenImageIds, isEmpty);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.failed);

      await cubit.close();
    });

    test('saveAllToPhotos saves only new, uploaded photos into the trip album and counts failures', () async {
      final repo = _FakeGalleryRepository(
        cached: {
          'new': _image('new'),
          'already-saved': _image('already-saved'),
          'undownloadable': _image('undownloadable', url: 'https://storage.test/broken'),
          'still-uploading': _image('still-uploading', status: EUploadStatus.failed),
        },
      )..savedToPhotos.add('already-saved');
      final saver = _FakePhotoSaveService(EPhotoLibraryAccess.album);
      final cubit = await openTrip(repo, photoSaver: saver);

      await cubit.saveAllToPhotos();

      expect(saver.albumBySavedPath, {'new.jpg': 'Xplore – Lisbon'});
      expect(
        cubit.state.saveProgress,
        const PhotoSaveProgress(phase: EPhotoSavePhase.done, total: 2, saved: 1, failed: 1, album: 'Xplore – Lisbon'),
      );
      // The failed photo stays unsaved, so the next run picks it up again.
      expect(repo.savedToPhotos, {'already-saved', 'new'});

      await cubit.close();
    });

    test('saveAllToPhotos saves loose photos when only add-only access is granted', () async {
      final saver = _FakePhotoSaveService(EPhotoLibraryAccess.addOnly);
      final cubit = await openTrip(_FakeGalleryRepository(cached: {'a': _image('a')}), photoSaver: saver);

      await cubit.saveAllToPhotos();

      expect(saver.albumBySavedPath, {'a.jpg': null});

      await cubit.close();
    });

    test('saveAllToPhotos saves nothing and reports it when photo access is denied', () async {
      final saver = _FakePhotoSaveService(EPhotoLibraryAccess.denied);
      final cubit = await openTrip(_FakeGalleryRepository(cached: {'a': _image('a')}), photoSaver: saver);

      await cubit.saveAllToPhotos();

      expect(saver.albumBySavedPath, isEmpty);
      expect(cubit.state.saveProgress?.phase, EPhotoSavePhase.denied);

      await cubit.close();
    });
  });
}
