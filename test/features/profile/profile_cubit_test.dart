// Tests for `ProfileCubit` cloud hydration (FEAT-015).
//
// A fake `ProfileService` feeds a controllable profile stream; the repository is
// a real `hive_ce` store in a temp dir. Proves the cubit applies cloud values to
// state and that the listener is the writer that fills the cache.

import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/profile/models/profile_models.dart';
import 'package:xplore/features/profile/repository/profile_repository.dart';
import 'package:xplore/features/profile/services/profile_service.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this.controller) : super(firestore: FakeFirebaseFirestore());

  final StreamController<UserProfile?> controller;

  @override
  Stream<UserProfile?> watchUserProfile(String uid) => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_profile_cubit_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('seeds the display name from the auth provider before hydration', () {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u1', displayName: 'Ada Lovelace'),
    );
    final cubit = ProfileCubit(authService, hydrate: false);
    addTearDown(cubit.close);

    expect(cubit.state.id, 'u1');
    expect(cubit.state.name, 'Ada Lovelace');
    expect(cubit.state.username, isNull);
  });

  test('hydrateProfile applies cloud values to state and writes them to the cache', () async {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u1', displayName: 'Ada Lovelace'),
    );
    final controller = StreamController<UserProfile?>();
    final service = _FakeProfileService(controller);
    final repo = ProfileRepository();
    final cubit = ProfileCubit(authService, profileService: service, profileRepository: repo, hydrate: false);
    addTearDown(cubit.close);
    addTearDown(controller.close);

    await cubit.hydrateProfile();
    controller.add(
      const UserProfile(
        uid: 'u1',
        displayName: 'Ada Lovelace',
        username: 'ada-1a2b',
        photoUrl: 'https://example.com/a.png',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.username, 'ada-1a2b');
    expect(cubit.state.photoUrl, 'https://example.com/a.png');
    expect(cubit.state.name, 'Ada Lovelace');

    final cached = await repo.loadFromCache('u1');
    expect(cached?.username, 'ada-1a2b');
  });
}
