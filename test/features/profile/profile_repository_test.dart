// Tests for `ProfileRepository` against a real `hive_ce` store (FEAT-015).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/profile/models/profile_models.dart';
import 'package:xplore/features/profile/repository/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_profile_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  const profile = UserProfile(
    uid: 'u1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    photoUrl: 'https://example.com/a.png',
    username: 'ada-1a2b',
  );

  test('cacheProfile persists a profile that loadFromCache restores', () async {
    final repo = ProfileRepository();

    await repo.cacheProfile(profile);
    final loaded = await repo.loadFromCache('u1');

    expect(loaded, isNotNull);
    expect(loaded!.username, 'ada-1a2b');
    expect(loaded.displayName, 'Ada Lovelace');
    expect(loaded.photoUrl, 'https://example.com/a.png');
  });

  test('loadFromCache returns null for an unknown uid', () async {
    final repo = ProfileRepository();
    expect(await repo.loadFromCache('missing'), isNull);
  });

  test('clear removes the cached profile', () async {
    final repo = ProfileRepository();
    await repo.cacheProfile(profile);

    await repo.clear('u1');

    expect(await repo.loadFromCache('u1'), isNull);
  });
}
