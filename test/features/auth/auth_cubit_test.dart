import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthCubit', () {
    test('starts in the unknown state before auth resolves', () {
      final cubit = AuthCubit(fakeAuthService(signedIn: false));
      expect(cubit.state, isA<AuthUnknown>());
      cubit.close();
    });

    test('resolves to authenticated for an existing session', () async {
      final user = MockUser(uid: 'abc123', displayName: 'Ada', email: 'ada@example.com');
      final cubit = AuthCubit(fakeAuthService(signedIn: true, user: user));

      await pumpEventQueue();

      expect(cubit.state, isA<AuthAuthenticated>());
      final state = cubit.state as AuthAuthenticated;
      expect(state.uid, 'abc123');
      expect(state.displayName, 'Ada');
      expect(state.email, 'ada@example.com');

      await cubit.close();
    });

    test('resolves to unauthenticated when there is no session', () async {
      final cubit = AuthCubit(fakeAuthService(signedIn: false));

      await pumpEventQueue();

      expect(cubit.state, isA<AuthUnauthenticated>());
      await cubit.close();
    });

    test('falls back to a default display name when none is provided', () async {
      final user = MockUser(uid: 'noname', displayName: '');
      final cubit = AuthCubit(fakeAuthService(signedIn: true, user: user));

      await pumpEventQueue();

      expect((cubit.state as AuthAuthenticated).displayName, 'Traveler');
      await cubit.close();
    });

    test('signOut transitions back to unauthenticated', () async {
      final cubit = AuthCubit(fakeAuthService(signedIn: true, user: MockUser(uid: 'abc123')));

      await pumpEventQueue();
      expect(cubit.state, isA<AuthAuthenticated>());

      await cubit.signOut();
      await pumpEventQueue();

      expect(cubit.state, isA<AuthUnauthenticated>());
      await cubit.close();
    });

    test('signInWithApple drives the stream to authenticated', () async {
      final service = AuthService(
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'apple-user', displayName: 'Jane Doe'),
        ),
        firestore: FakeFirebaseFirestore(),
        appleCredentialRequester: ({required scopes, nonce}) async => const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: 'Jane',
          familyName: 'Doe',
          authorizationCode: 'auth-code',
          email: 'jane@privaterelay.appleid.com',
          identityToken: 'apple-id-token',
          state: null,
        ),
      );
      final cubit = AuthCubit(service);

      await pumpEventQueue();
      expect(cubit.state, isA<AuthUnauthenticated>());

      await cubit.signInWithApple();
      await pumpEventQueue();

      expect(cubit.state, isA<AuthAuthenticated>());
      expect((cubit.state as AuthAuthenticated).uid, 'apple-user');
      await cubit.close();
    });
  });
}
