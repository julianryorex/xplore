import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/features/gallery/services/gallery_service.dart';
import 'package:xplore/features/gallery/services/photo_content_hash.dart';
import 'package:xplore/features/gallery/services/photo_save_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

import '../../helpers/auth_fixtures.dart';

/// In-memory stand-in for the Hive + file cache, keyed by trip like the real one.
class _FakeGalleryRepository extends GalleryRepository {
  final Map<String, Map<String, ImageModel>> metadata = {};
  final Map<String, Set<String>> savedToPhotos = {};

  /// `<tripId>/<imageId>` of every full-resolution original "on disk".
  final Set<String> fullRes = {};

  /// `<tripId>/<imageId>` of originals handed back to the purgeable cache after upload.
  final List<String> released = [];

  void seed(String tripId, List<ImageModel> images, {Set<String> withOriginals = const {}}) {
    metadata[tripId] = {for (final image in images) image.id: image};
    fullRes.addAll(withOriginals.map((id) => '$tripId/$id'));
  }

  @override
  Future<Map<String, ImageModel>> loadImgFromCache(String tripId) async => {...?metadata[tripId]};

  @override
  Future<void> cacheMetadata(String tripId, ImageModel imageModel) async =>
      metadata.putIfAbsent(tripId, () => {})[imageModel.id] = imageModel;

  @override
  Future<File?> fullResFile(String tripId, String id) async => fullRes.contains('$tripId/$id') ? File('$id.jpg') : null;

  @override
  Future<File> cacheFullRes(String tripId, String id, File source) async {
    fullRes.add('$tripId/$id');
    return File('$id.jpg');
  }

  @override
  Future<File> fetchAndCacheFullRes(String tripId, String id, String url) async {
    if (url.contains('broken')) throw const HttpException('Download failed');
    return File('$id.jpg');
  }

  @override
  Future<void> releaseUploadedOriginal(String tripId, String id) async => released.add('$tripId/$id');

  @override
  Future<void> closeTrip(String tripId) async {}

  @override
  Future<Set<String>> loadSavedPhotoIds(String tripId) async => {...?savedToPhotos[tripId]};

  @override
  Future<void> markPhotoSaved(String tripId, String id) async => savedToPhotos.putIfAbsent(tripId, () => {}).add(id);
}

class _FakeGalleryService implements GalleryService {
  final Map<String, StreamController<List<ImageModel>>> _remote = {};

  /// `<tripId>/<imageId>` of every published metadata doc.
  final List<String> published = [];

  void pushRemote(String tripId, List<ImageModel> images) => _controller(tripId).add(images);

  StreamController<List<ImageModel>> _controller(String tripId) =>
      _remote.putIfAbsent(tripId, StreamController<List<ImageModel>>.broadcast);

  @override
  Stream<List<ImageModel>> watchTripImages(String tripId) => _controller(tripId).stream;

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
    String? contentHash,
  }) async => published.add('$tripId/$imageId');
}

class _FakePhotoSaveService implements PhotoSaveService {
  _FakePhotoSaveService(this.access);

  final EPhotoLibraryAccess access;

  /// When set, [requestAccess] waits on it, like a permission prompt left open.
  Completer<void>? prompt;
  final List<String> savedPaths = [];
  String? lastAlbum;

  @override
  Future<EPhotoLibraryAccess> requestAccess() async {
    await prompt?.future;
    return access;
  }

  @override
  Future<void> saveImage(File file, {String? album}) async {
    savedPaths.add(file.path);
    lastAlbum = album;
  }

  @override
  Future<void> openPhotosApp() async {}
}

/// Cubit whose Storage upload is replaced, so the rest of the upload flow runs for real.
class _OfflineStorageGalleryCubit extends GalleryCubit {
  _OfflineStorageGalleryCubit(super.authService, {super.repo, super.service, super.photoSaver});

  /// When set, uploads wait on it, like a slow network.
  Completer<void>? network;
  final List<String> uploadedPaths = [];

  @override
  Future<String> uploadImage(File imageFile, String storagePath) async {
    await network?.future;
    uploadedPaths.add(storagePath);
    return 'https://storage.test/$storagePath';
  }
}

const _lisbon = TripModel(id: 'lisbon', title: 'Lisbon', memberIds: ['me'], createdBy: 'me');
const _tokyo = TripModel(id: 'tokyo', title: 'Tokyo', memberIds: ['me'], createdBy: 'me');

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

/// Waits for the cubit's un-awaited work (thumbnail isolates, uploads) to reach [condition].
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition was not reached in time.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGalleryRepository repo;
  late _FakeGalleryService service;
  late _OfflineStorageGalleryCubit cubit;

  Future<void> open(TripModel trip) async {
    cubit.pushTripEvent(TripState.loaded(active: trip, all: const [_lisbon, _tokyo]));
    await pumpEventQueue();
  }

  void build({bool signedIn = true, PhotoSaveService? photoSaver}) {
    cubit = _OfflineStorageGalleryCubit(
      fakeAuthService(
        signedIn: signedIn,
        user: MockUser(uid: 'me', displayName: 'Mara Lindqvist'),
      ),
      repo: repo,
      service: service,
      photoSaver: photoSaver,
    );
  }

  setUp(() {
    repo = _FakeGalleryRepository();
    service = _FakeGalleryService();
    build();
  });

  tearDown(() => cubit.close());

  group('cloud sync', () {
    test('merges remote photos: adds other members\' and completes our own, keeping the local thumbnail', () async {
      final localThumbnail = Uint8List.fromList([1, 2, 3]);
      repo.seed('lisbon', [_image('mine', status: EUploadStatus.failed, thumbnail: localThumbnail)]);
      await open(_lisbon);
      expect(cubit.state.hasSyncedWithCloud, isFalse);

      service.pushRemote('lisbon', [_image('mine'), _image('theirs')]);
      await pumpEventQueue();

      final images = cubit.state.imageMap;
      expect(images.keys, unorderedEquals(['mine', 'theirs']));
      expect(images['mine']!.isUploading, EUploadStatus.complete);
      expect(images['mine']!.downloadUrl, isNotNull);
      expect(images['mine']!.lowResImage, localThumbnail);
      expect(cubit.state.hasSyncedWithCloud, isTrue);
      // Remote photos are cached so the gallery is populated offline next launch.
      expect(repo.metadata['lisbon']!.keys, containsAll(['mine', 'theirs']));
    });

    test('switching trips shows only the new trip\'s photos', () async {
      repo.seed('lisbon', [_image('lisbon-photo')]);
      repo.seed('tokyo', [_image('tokyo-photo')]);
      await open(_lisbon);

      await open(_tokyo);
      // A late snapshot for the trip that was left must not leak into the one on screen.
      service.pushRemote('lisbon', [_image('late-lisbon-photo')]);
      await pumpEventQueue();

      expect(cubit.state.imageMap.keys, ['tokyo-photo']);
    });
  });

  group('uploading', () {
    late Directory tempDir;
    late XFile picked;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gallery_cubit_test');
      final file = File('${tempDir.path}/picked.jpg');
      await file.writeAsBytes(_jpeg);
      picked = XFile(file.path);
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('an added photo shows at once with its uploader, then uploads and is published', () async {
      await open(_lisbon);
      cubit.network = Completer<void>();

      await cubit.addPhotos('lisbon', [picked]);

      final added = cubit.state.imageMap.values.single;
      expect(added.isUploading, EUploadStatus.uploading);
      expect(added.uploaderUid, 'me');
      expect(added.uploaderName, 'Mara');
      expect(repo.fullRes, {'lisbon/${added.id}'});

      cubit.network!.complete();
      await _until(() => cubit.state.imageMap[added.id]!.isUploading == EUploadStatus.complete);

      expect(cubit.uploadedPaths, ['gallery/lisbon/me/${added.id}']);
      expect(service.published, ['lisbon/${added.id}']);
      expect(repo.released, ['lisbon/${added.id}']);
    });

    test('a photo the trip already has is skipped and reported, not added again', () async {
      await open(_lisbon);
      await cubit.addPhotos('lisbon', [picked]);
      await _until(() => service.published.length == 1);

      // The same file twice more: once against the album, once within the pick.
      await cubit.addPhotos('lisbon', [picked, picked]);

      expect(cubit.state.imageMap, hasLength(1));
      expect(cubit.state.duplicatesSkipped, 2);
      expect(service.published, hasLength(1));
    });

    test('a photo another member already added is skipped too', () async {
      await open(_lisbon);
      final theirs = _image('theirs').copyWith(contentHash: photoContentHash(_jpeg));
      service.pushRemote('lisbon', [theirs]);
      await pumpEventQueue();

      await cubit.addPhotos('lisbon', [picked]);

      expect(cubit.state.imageMap.keys, ['theirs']);
      expect(cubit.state.duplicatesSkipped, 1);
    });

    // Regression: photos used to follow whichever trip was active when each await resumed.
    test('photos picked for one trip stay in that trip when another becomes active', () async {
      await open(_lisbon);
      await open(_tokyo);

      await cubit.addPhotos('lisbon', [picked]);
      await _until(() => service.published.isNotEmpty);

      final id = repo.metadata['lisbon']!.keys.single;
      expect(cubit.state.imageMap, isEmpty);
      expect(repo.metadata['tokyo'], isNull);
      expect(repo.fullRes, {'lisbon/$id'});
      expect(cubit.uploadedPaths, ['gallery/lisbon/me/$id']);
      expect(service.published, ['lisbon/$id']);
      expect(repo.metadata['lisbon']![id]!.isUploading, EUploadStatus.complete);
    });

    test('an upload that finishes after a trip switch completes in its own trip', () async {
      repo.seed('lisbon', [_image('stuck', status: EUploadStatus.failed)], withOriginals: {'stuck'});
      await open(_lisbon);
      cubit.network = Completer<void>();
      final retry = cubit.retryUpload('stuck');
      await pumpEventQueue();

      await open(_tokyo);
      cubit.network!.complete();
      await retry;

      expect(cubit.state.imageMap, isEmpty);
      expect(repo.metadata['lisbon']!['stuck']!.isUploading, EUploadStatus.complete);

      // Coming back shows it as uploaded.
      await open(_lisbon);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.complete);
    });

    test('an upload interrupted by an app restart is shown as failed so it can be retried', () async {
      repo.seed('lisbon', [_image('stuck', status: EUploadStatus.uploading)]);

      await open(_lisbon);

      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.failed);
    });

    test('retryUpload re-uploads from the cached original and publishes the photo', () async {
      repo.seed('lisbon', [_image('stuck', status: EUploadStatus.failed)], withOriginals: {'stuck'});
      await open(_lisbon);

      await cubit.retryUpload('stuck');

      expect(service.published, ['lisbon/stuck']);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.complete);
      expect(repo.metadata['lisbon']!['stuck']!.downloadUrl, 'https://storage.test/gallery/lisbon/me/stuck');
    });

    test('retryUpload keeps the photo failed when its original is gone', () async {
      repo.seed('lisbon', [_image('stuck', status: EUploadStatus.failed)]);
      await open(_lisbon);

      await cubit.retryUpload('stuck');

      expect(service.published, isEmpty);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.failed);
    });

    // The Storage path is uid-scoped, so a signed-out upload must fail rather than guess an owner.
    test('nothing is uploaded while signed out', () async {
      await cubit.close();
      build(signedIn: false);
      repo.seed('lisbon', [_image('stuck', status: EUploadStatus.failed)], withOriginals: {'stuck'});
      await open(_lisbon);

      await cubit.retryUpload('stuck');

      expect(cubit.uploadedPaths, isEmpty);
      expect(service.published, isEmpty);
      expect(cubit.state.imageMap['stuck']!.isUploading, EUploadStatus.failed);
    });
  });

  group('saveAllToPhotos', () {
    late _FakePhotoSaveService saver;

    Future<void> openWith(EPhotoLibraryAccess access, List<ImageModel> images, {Set<String> saved = const {}}) async {
      await cubit.close();
      saver = _FakePhotoSaveService(access);
      build(photoSaver: saver);
      repo.seed('lisbon', images);
      repo.savedToPhotos['lisbon'] = {...saved};
      await open(_lisbon);
    }

    test('saves only new, uploaded photos into the trip album and counts failures', () async {
      await openWith(
        EPhotoLibraryAccess.album,
        [
          _image('new'),
          _image('already-saved'),
          _image('undownloadable', url: 'https://storage.test/broken'),
          _image('not-uploaded', status: EUploadStatus.failed),
        ],
        saved: {'already-saved'},
      );

      await cubit.saveAllToPhotos();

      expect(saver.savedPaths, ['new.jpg']);
      expect(saver.lastAlbum, 'Xplore – Lisbon');
      expect(
        cubit.state.saveProgress,
        const PhotoSaveProgress(phase: EPhotoSavePhase.done, total: 2, saved: 1, failed: 1, album: 'Xplore – Lisbon'),
      );
      // The failed photo stays unsaved, so the next run picks it up again.
      expect(repo.savedToPhotos['lisbon'], {'already-saved', 'new'});
      expect(cubit.state.unsavedPhotos.map((image) => image.id), ['undownloadable']);
    });

    test('saves loose photos when only add-only access is granted', () async {
      await openWith(EPhotoLibraryAccess.addOnly, [_image('a')]);

      await cubit.saveAllToPhotos();

      expect(saver.savedPaths, ['a.jpg']);
      expect(saver.lastAlbum, isNull);
    });

    test('saves nothing and reports it when photo access is denied', () async {
      await openWith(EPhotoLibraryAccess.denied, [_image('a')]);

      await cubit.saveAllToPhotos();

      expect(saver.savedPaths, isEmpty);
      expect(cubit.state.saveProgress?.phase, EPhotoSavePhase.denied);
    });

    test('a second tap while a run is starting does not save every photo twice', () async {
      await openWith(EPhotoLibraryAccess.album, [_image('a'), _image('b')]);
      saver.prompt = Completer<void>();

      final first = cubit.saveAllToPhotos();
      final second = cubit.saveAllToPhotos();
      saver.prompt!.complete();
      await Future.wait([first, second]);

      expect(saver.savedPaths, hasLength(2));
    });

    test('a trip switch during the permission prompt abandons the run', () async {
      await openWith(EPhotoLibraryAccess.album, [_image('a')]);
      saver.prompt = Completer<void>();
      final run = cubit.saveAllToPhotos();

      await open(_tokyo);
      saver.prompt!.complete();
      await run;

      expect(saver.savedPaths, isEmpty);
      expect(cubit.state.saveProgress, isNull);
      // Save all still works on the trip now on screen.
      repo.seed('tokyo', [_image('t')]);
      await open(_lisbon);
      await open(_tokyo);
      await cubit.saveAllToPhotos();
      expect(saver.savedPaths, ['t.jpg']);
    });
  });
}
