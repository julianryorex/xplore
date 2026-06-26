// Tests for `ProfileService.watchUserProfile` against an in-memory Firestore
// fake (FEAT-015). The avatar upload path needs Firebase Storage and is covered
// at the cubit/integration level instead.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/profile/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('watchUserProfile emits null while the document is absent', () async {
    final firestore = FakeFirebaseFirestore();
    final service = ProfileService(firestore: firestore);

    expect(await service.watchUserProfile('u1').first, isNull);
  });

  test('watchUserProfile maps the document into a UserProfile (ignoring extra fields)', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({
      'displayName': 'Ada Lovelace',
      'email': 'ada@example.com',
      'photoUrl': 'https://example.com/a.png',
      'username': 'ada-1a2b',
      'usernameLower': 'ada-1a2b',
      'providers': ['google'],
    });
    final service = ProfileService(firestore: firestore);

    final profile = await service.watchUserProfile('u1').first;

    expect(profile, isNotNull);
    expect(profile!.uid, 'u1');
    expect(profile.displayName, 'Ada Lovelace');
    expect(profile.username, 'ada-1a2b');
    expect(profile.photoUrl, 'https://example.com/a.png');
  });

  test('setPhotoUrl merges the avatar URL onto the profile', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({'displayName': 'Ada'});
    final service = ProfileService(firestore: firestore);

    await service.setPhotoUrl('u1', 'https://example.com/new.png');

    final doc = await firestore.collection('users').doc('u1').get();
    expect(doc.data()!['photoUrl'], 'https://example.com/new.png');
    expect(doc.data()!['displayName'], 'Ada', reason: 'merge must not clobber other fields');
  });
}
