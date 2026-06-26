import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';

import '../../helpers/auth_fixtures.dart';

/// Repository that skips Hive so the cubit can be constructed in a unit test.
class _EmptyGalleryRepository extends GalleryRepository {
  @override
  Future<Map<String, ImageModel>> loadImgFromCache() async => {};
}

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
}
