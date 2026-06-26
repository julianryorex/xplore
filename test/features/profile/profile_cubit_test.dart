// Tests for `ProfileCubit` cloud hydration (FEAT-015).
//
// A fake `ProfileService` feeds a controllable profile stream; the repository is
// a real `hive_ce` store in a temp dir. Proves the cubit applies cloud values to
// state and that the listener is the writer that fills the cache.

import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/profile/models/profile_models.dart';
import 'package:xplore/features/profile/repository/profile_repository.dart';
import 'package:xplore/features/profile/services/profile_service.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this.controller, {this.avatarBytes}) : super(firestore: FakeFirebaseFirestore());

  final StreamController<UserProfile?> controller;
  final Uint8List? avatarBytes;
  int downloadCount = 0;

  @override
  Stream<UserProfile?> watchUserProfile(String uid) => controller.stream;

  @override
  Future<Uint8List?> downloadAvatar(String uid) async {
    downloadCount++;
    return avatarBytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // Stand in for the on-device app-documents dir so the avatar file path
  // (profile_picture.png) resolves to the temp dir instead of hanging on the
  // unimplemented platform channel.
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_profile_cubit_test');
    Hive.init(tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
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

  test('downloads the cloud avatar into profilePicture when no local bytes exist', () async {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u1', displayName: 'Ada Lovelace'),
    );
    final controller = StreamController<UserProfile?>();
    final avatar = Uint8List.fromList([9, 8, 7, 6]);
    final service = _FakeProfileService(controller, avatarBytes: avatar);
    final cubit = ProfileCubit(
      authService,
      profileService: service,
      profileRepository: ProfileRepository(),
      hydrate: false,
    );
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
    // Let the download → emit → local-file-write chain settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cubit.state.profilePicture, avatar, reason: 'cloud avatar bytes must hydrate the home/marker source');
    expect(
      File('${tempDir.path}/profile_picture.png').readAsBytesSync(),
      avatar,
      reason: 'fetched bytes must be cached locally for offline / instant loads',
    );
  });

  test('does not download the avatar when the cloud profile has no photoUrl', () async {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u1', displayName: 'Ada Lovelace'),
    );
    final controller = StreamController<UserProfile?>();
    final service = _FakeProfileService(controller, avatarBytes: Uint8List.fromList([1]));
    final cubit = ProfileCubit(
      authService,
      profileService: service,
      profileRepository: ProfileRepository(),
      hydrate: false,
    );
    addTearDown(cubit.close);
    addTearDown(controller.close);

    await cubit.hydrateProfile();
    controller.add(const UserProfile(uid: 'u1', displayName: 'Ada Lovelace', username: 'ada-1a2b'));
    await Future<void>.delayed(Duration.zero);

    expect(service.downloadCount, 0);
    expect(cubit.state.profilePicture, isNull);
  });

  test('onSignedOut clears the cached profile and resets in-memory state', () async {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u1', displayName: 'Ada Lovelace'),
    );
    final repo = ProfileRepository();
    final cubit = ProfileCubit(authService, profileRepository: repo, hydrate: false);
    addTearDown(cubit.close);

    await repo.cacheProfile(const UserProfile(uid: 'u1', displayName: 'Ada Lovelace', username: 'ada-1a2b'));
    expect(await repo.loadFromCache('u1'), isNotNull);

    // The avatar lives at a fixed (non-uid) path — the key cross-account leak.
    final avatarFile = File('${tempDir.path}/profile_picture.png');
    await avatarFile.writeAsBytes([1, 2, 3]);

    await cubit.onSignedOut();

    expect(avatarFile.existsSync(), isFalse, reason: 'local avatar file must be deleted on sign-out');
    expect(await repo.loadFromCache('u1'), isNull, reason: 'profile cache must be wiped on sign-out');
    expect(cubit.state.id, isEmpty);
    expect(cubit.state.name, isEmpty);
    expect(cubit.state.username, isNull);
    expect(cubit.state.photoUrl, isNull);
    expect(cubit.state.profilePicture, isNull);
  });

  test('onSignedIn seeds the new account and re-hydrates from the cloud', () async {
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'u2', displayName: 'Grace Hopper'),
    );
    final controller = StreamController<UserProfile?>();
    final service = _FakeProfileService(controller);
    final repo = ProfileRepository();
    final cubit = ProfileCubit(authService, profileService: service, profileRepository: repo, hydrate: false);
    addTearDown(cubit.close);
    addTearDown(controller.close);

    await cubit.onSignedIn('u2');
    expect(cubit.state.id, 'u2');
    expect(cubit.state.name, 'Grace Hopper');

    controller.add(const UserProfile(uid: 'u2', displayName: 'Grace Hopper', username: 'grace-9z9z'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.username, 'grace-9z9z');
  });
}
