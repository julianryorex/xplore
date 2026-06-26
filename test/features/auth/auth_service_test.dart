import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// Builds an [AppleCredentialRequester] that returns a canned Apple credential,
/// standing in for the native authorization sheet.
AppleCredentialRequester _fakeAppleRequester({
  String? identityToken = 'apple-id-token',
  String? givenName = 'Jane',
  String? familyName = 'Doe',
  String? email = 'jane@privaterelay.appleid.com',
}) {
  return ({required scopes, nonce}) async => AuthorizationCredentialAppleID(
    userIdentifier: 'apple-user',
    givenName: givenName,
    familyName: familyName,
    authorizationCode: 'auth-code',
    email: email,
    identityToken: identityToken,
    state: null,
  );
}

AuthService _appleAuthService({
  required FakeFirebaseFirestore firestore,
  MockUser? user,
  AppleCredentialRequester? requester,
}) {
  return AuthService(
    firebaseAuth: MockFirebaseAuth(
      mockUser: user ?? MockUser(uid: 'apple-user', displayName: ''),
    ),
    firestore: firestore,
    appleCredentialRequester: requester ?? _fakeAppleRequester(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService.signInWithApple', () {
    test('signs in and upserts the users/{uid} profile with the apple provider', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(firestore: firestore);

      final credential = await service.signInWithApple();

      expect(credential.user, isNotNull);
      expect(service.currentUid, 'apple-user');

      final doc = await firestore.collection('users').doc('apple-user').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['providers'], contains('apple'));
      expect(doc.data()!['createdAt'], isNotNull);
    });

    test('captures the Apple display name on first authorization', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(firestore: firestore);

      await service.signInWithApple();

      expect(service.currentUser!.displayName, 'Jane Doe');
      final doc = await firestore.collection('users').doc('apple-user').get();
      expect(doc.data()!['displayName'], 'Jane Doe');
    });

    test('does not overwrite an existing display name when Apple omits the name', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(
        firestore: firestore,
        user: MockUser(uid: 'apple-user', displayName: 'Existing Name'),
        requester: _fakeAppleRequester(givenName: null, familyName: null),
      );

      await service.signInWithApple();

      expect(service.currentUser!.displayName, 'Existing Name');
    });

    test('maps a user cancellation to AuthCancelledException', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(
        firestore: firestore,
        requester: ({required scopes, nonce}) async => throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'cancelled',
        ),
      );

      await expectLater(service.signInWithApple(), throwsA(isA<AuthCancelledException>()));
    });

    test('maps other Apple authorization errors to AuthFailureException', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(
        firestore: firestore,
        requester: ({required scopes, nonce}) async =>
            throw const SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.failed, message: 'boom'),
      );

      await expectLater(service.signInWithApple(), throwsA(isA<AuthFailureException>()));
    });

    test('throws AuthFailureException when Apple returns no identity token', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _appleAuthService(firestore: firestore, requester: _fakeAppleRequester(identityToken: null));

      await expectLater(service.signInWithApple(), throwsA(isA<AuthFailureException>()));
    });
  });

  group('AuthService.deleteAccount', () {
    MockUser appleUser() => MockUser(
      uid: 'apple-user',
      displayName: 'Jane Doe',
      providerData: [
        UserInfo.fromPigeon(
          InternalUserInfo(uid: 'apple-user', providerId: 'apple.com', isAnonymous: false, isEmailVerified: true),
        ),
      ],
    );

    test('re-auths, revokes the Apple token, and deletes the users/{uid} profile', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('apple-user').set({'displayName': 'Jane Doe'});

      String? revokedCode;
      final service = AuthService(
        firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: appleUser()),
        firestore: firestore,
        appleCredentialRequester: _fakeAppleRequester(),
        appleTokenRevoker: (code) async => revokedCode = code,
      );

      await service.deleteAccount();

      expect(revokedCode, 'auth-code');
      final doc = await firestore.collection('users').doc('apple-user').get();
      expect(doc.exists, isFalse);
    });

    test('maps re-auth cancellation to AuthCancelledException without deleting data', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('apple-user').set({'displayName': 'Jane Doe'});

      var revokeCalled = false;
      final service = AuthService(
        firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: appleUser()),
        firestore: firestore,
        appleCredentialRequester: ({required scopes, nonce}) async => throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'cancelled',
        ),
        appleTokenRevoker: (code) async => revokeCalled = true,
      );

      await expectLater(service.deleteAccount(), throwsA(isA<AuthCancelledException>()));
      expect(revokeCalled, isFalse);
      final doc = await firestore.collection('users').doc('apple-user').get();
      expect(doc.exists, isTrue);
    });

    test('throws AuthFailureException when there is no signed-in user', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AuthService(firebaseAuth: MockFirebaseAuth(), firestore: firestore);

      await expectLater(service.deleteAccount(), throwsA(isA<AuthFailureException>()));
    });
  });
}
