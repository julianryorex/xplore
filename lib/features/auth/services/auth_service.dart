import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:xplore/utilities/utilities.dart';

/// Thrown when the user cancels an interactive sign-in. Non-blocking: the UI
/// should simply return to the idle sign-in state.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// Thrown for any non-cancellation sign-in failure (network, token, Firebase).
class AuthFailureException implements Exception {
  final String message;

  const AuthFailureException(this.message);

  @override
  String toString() => 'AuthFailureException: $message';
}

/// Single source of UID truth for the app.
///
/// A plain service (no Flutter / bloc imports) composed into [AuthCubit] and the
/// feature cubits (Profile / Location / Map) via constructor injection — see the
/// "cubits never import cubits" rule in `docs/PATTERNS.md`. Wraps [FirebaseAuth]
/// + Google sign-in and upserts the Firestore `users/{uid}` profile in the named
/// `xplore-app` database created by the Terraform infra.
///
/// Google is the first provider (interim, while Apple Developer enrollment is
/// unavailable). Adding Apple later is additive: a `signInWithApple()` method
/// here plus a button in the sign-in UI — no structural change.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore, GoogleSignIn? googleSignIn})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: appDatabaseId),
      _google = googleSignIn ?? GoogleSignIn.instance;

  /// Named Firestore Native database created by the Terraform infra (Phase 1).
  /// The project's default database is Datastore-mode and unusable by the SDKs.
  static const appDatabaseId = 'xplore-app';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _google;
  final Logger _logger = createLogger('AuthService');

  bool _googleInitialized = false;

  /// Emits on every auth state change (sign-in, sign-out, token refresh).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// The current Firebase UID, or null when unauthenticated.
  String? get currentUid => _auth.currentUser?.uid;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      _logger.w('GoogleSignIn already initialized; skipping initialization.');
      return;
    }
    // On iOS the client ID is read from GoogleService-Info.plist, and Firebase
    // accepts an ID token issued for any OAuth client in the same project, so no
    // serverClientId is needed here. (Pass one if/when we add web or Android.)
    await _google.initialize();
    _googleInitialized = true;
  }

  /// Interactive Google sign-in -> Firebase credential -> `users/{uid}` upsert.
  ///
  /// Throws [AuthCancelledException] if the user backs out, or
  /// [AuthFailureException] on any other error.
  Future<UserCredential> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final account = await _google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        throw const AuthFailureException('Google did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw const AuthFailureException('Firebase returned no user.');
      }

      await _upsertUserProfile(user, provider: 'google');
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthFailureException(e.description ?? 'Google sign-in failed.');
    } on FirebaseAuthException catch (e) {
      throw AuthFailureException(e.message ?? 'Authentication failed.');
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Best-effort: Firebase sign-out below is the source of truth.
    }
    await _auth.signOut();
  }

  /// Creates or refreshes `users/{uid}`. `createdAt` is written once;
  /// `lastSeenAt` and the `providers` set are always updated.
  Future<void> _upsertUserProfile(User user, {required String provider}) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'displayName': user.displayName ?? '',
      'email': user.email,
      'photoUrl': user.photoURL,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'providers': FieldValue.arrayUnion([provider]),
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }
}
