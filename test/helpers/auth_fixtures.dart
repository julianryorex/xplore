import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// Builds an [AuthService] backed by in-memory Firebase fakes.
///
/// Centralises the mock wiring that previously lived (identically) in the
/// auth / gallery / profile tests so the UID-truth contract is exercised the
/// same way everywhere.
AuthService fakeAuthService({bool signedIn = false, MockUser? user}) {
  return AuthService(
    firebaseAuth: MockFirebaseAuth(signedIn: signedIn, mockUser: user),
    firestore: FakeFirebaseFirestore(),
  );
}

/// A [MockFirebaseAuth] whose email/password sign-in always fails with
/// [message], standing in for wrong credentials or a disabled provider.
class RejectingEmailPasswordAuth extends MockFirebaseAuth {
  RejectingEmailPasswordAuth({this.message = 'Wrong credentials.'});

  final String message;

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    throw FirebaseAuthException(code: 'invalid-credential', message: message);
  }
}
