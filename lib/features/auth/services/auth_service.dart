import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:xplore/utilities/utilities.dart';

/// Requests an Apple ID credential. Defaults to the real
/// [SignInWithApple.getAppleIDCredential]; overridable in tests so the native
/// authorization sheet doesn't have to run.
typedef AppleCredentialRequester =
    Future<AuthorizationCredentialAppleID> Function({required List<AppleIDAuthorizationScopes> scopes, String? nonce});

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
/// Apple is the primary provider (App Store policy); Google is also supported.
/// Both funnel through Firebase credentials and the same `users/{uid}` upsert.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    AppleCredentialRequester? appleCredentialRequester,
    Future<void> Function(String authorizationCode)? appleTokenRevoker,
    Future<void> Function()? googleAuthorizationRevoker,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: appDatabaseId),
       _google = googleSignIn ?? GoogleSignIn.instance,
       _requestAppleCredential = appleCredentialRequester ?? SignInWithApple.getAppleIDCredential,
       // Fields are private; the public-facing param names can't be initializing formals.
       // ignore: prefer_initializing_formals
       _appleTokenRevoker = appleTokenRevoker,
       // ignore: prefer_initializing_formals
       _googleAuthorizationRevoker = googleAuthorizationRevoker;

  /// Named Firestore Native database created by the Terraform infra (Phase 1).
  /// The project's default database is Datastore-mode and unusable by the SDKs.
  static const appDatabaseId = 'xplore-app';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _google;
  final AppleCredentialRequester _requestAppleCredential;

  /// Apple token revocation seam. Defaults to [FirebaseAuth.revokeTokenWithAuthorizationCode]
  /// at call time; overridable in tests (the mock doesn't implement it).
  final Future<void> Function(String authorizationCode)? _appleTokenRevoker;

  /// Google authorization revocation seam. Defaults to the real
  /// [GoogleSignIn.disconnect] flow; overridable in tests (the v7 SDK can't be
  /// constructed with fakes).
  final Future<void> Function()? _googleAuthorizationRevoker;

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

  /// Interactive Sign in with Apple -> Firebase credential -> `users/{uid}`
  /// upsert. The primary provider (App Store policy mandates Apple when offering
  /// third-party sign-in on iOS).
  ///
  /// Throws [AuthCancelledException] if the user backs out, or
  /// [AuthFailureException] on any other error.
  Future<UserCredential> signInWithApple() async {
    // A nonce ties the Apple ID token to this request (replay protection). The
    // SHA-256 digest goes to Apple; the raw value goes to Firebase to verify.
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    try {
      final appleCredential = await _requestAppleCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw const AuthFailureException('Apple did not return an identity token.');
      }

      final credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: idToken, rawNonce: rawNonce, accessToken: appleCredential.authorizationCode);
      final userCredential = await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw const AuthFailureException('Firebase returned no user.');
      }

      // Apple only sends the name on the *first* authorization and never
      // populates FirebaseAuth.displayName, so capture it now or it's lost.
      await _captureAppleDisplayName(user, appleCredential);

      await _upsertUserProfile(user, provider: 'apple');
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthFailureException(e.message);
    } on FirebaseAuthException catch (e) {
      throw AuthFailureException(e.message ?? 'Authentication failed.');
    }
  }

  Future<void> _captureAppleDisplayName(User user, AuthorizationCredentialAppleID appleCredential) async {
    final hasName = (user.displayName ?? '').trim().isNotEmpty;
    if (hasName) return;

    final fullName = [appleCredential.givenName, appleCredential.familyName].whereType<String>().join(' ').trim();

    if (fullName.isEmpty) return;
    await user.updateDisplayName(fullName);
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Best-effort: Firebase sign-out below is the source of truth.
    }
    await _auth.signOut();
  }

  /// Permanently deletes the signed-in account.
  ///
  /// Re-authenticates with the user's provider (deletion is a privileged op that
  /// requires a recent login), removes the Firestore `users/{uid}` profile, then
  /// deletes the Firebase user. The `authStateChanges` stream then emits null,
  /// routing the app back to onboarding.
  ///
  /// Linked accounts: a single Firebase user can have BOTH `apple.com` and
  /// `google.com` linked. We only need one successful re-auth, but we revoke
  /// EVERY linked provider so neither service is left thinking the app still has
  /// access — Apple via [FirebaseAuth.revokeTokenWithAuthorizationCode] (App
  /// Store 5.1.1(v)) and Google via [GoogleSignIn.disconnect]. We prefer Apple
  /// for re-auth because its interactive flow also yields the authorization code
  /// the revoke call requires. Revocation is best-effort: a transient failure is
  /// logged rather than stranding the user with an undeletable account.
  ///
  /// Throws [AuthCancelledException] if the user backs out of the re-auth sheet,
  /// or [AuthFailureException] on any other error.
  ///
  /// NOTE (Tier 1): trip memberships, gallery objects and RTDB location nodes
  /// are NOT cascaded here — that requires a privileged backend (Tier 2).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailureException('No signed-in user to delete.');
    }

    final providerIds = user.providerData.map((info) => info.providerId).toSet();
    final hasApple = providerIds.contains('apple.com');
    final hasGoogle = providerIds.contains('google.com');

    try {
      // 1. Re-authenticate once. Prefer Apple so we also capture the
      //    authorization code needed to revoke its token below.
      AuthorizationCredentialAppleID? appleCredential;
      var reauthedViaGoogle = false;
      if (hasApple) {
        appleCredential = await _appleReauth(user);
      } else if (hasGoogle) {
        await _googleReauth(user);
        reauthedViaGoogle = true;
      }

      // 2. Purge app data while still authenticated (rules require request.auth).
      await _deleteUserData(user.uid);

      // 3. Notify every linked provider before the user is gone.
      if (hasApple && appleCredential != null) {
        await _revokeApple(appleCredential.authorizationCode);
      }
      if (hasGoogle) {
        await _revokeGoogle(alreadyAuthenticated: reauthedViaGoogle);
      }

      // 4. Delete the Firebase user. With no known interactive provider this is
      //    a direct delete and may throw requires-recent-login.
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailureException(e.message ?? 'Account deletion failed.');
    }
  }

  /// Runs the interactive Apple flow and re-authenticates [user], returning the
  /// credential (its `authorizationCode` is needed to revoke the Apple token).
  Future<AuthorizationCredentialAppleID> _appleReauth(User user) async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await _requestAppleCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthFailureException(e.message);
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw const AuthFailureException('Apple did not return an identity token.');
    }

    final credential = OAuthProvider(
      'apple.com',
    ).credential(idToken: idToken, rawNonce: rawNonce, accessToken: appleCredential.authorizationCode);
    await user.reauthenticateWithCredential(credential);
    return appleCredential;
  }

  /// Runs the interactive Google flow and re-authenticates [user].
  Future<void> _googleReauth(User user) async {
    try {
      await _ensureGoogleInitialized();
      final account = await _google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailureException('Google did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await user.reauthenticateWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthFailureException(e.description ?? 'Google re-authentication failed.');
    }
  }

  /// Revokes the Apple refresh token so the app is removed from the user's Apple
  /// ID settings (App Store 5.1.1(v)). Best-effort: logged, never fatal.
  Future<void> _revokeApple(String authorizationCode) async {
    try {
      await (_appleTokenRevoker ?? _auth.revokeTokenWithAuthorizationCode)(authorizationCode);
    } catch (e) {
      _logger.w('Apple token revocation failed; continuing with deletion: $e');
    }
  }

  /// Revokes the Google OAuth grant via [GoogleSignIn.disconnect]. When the
  /// Google flow wasn't already run for re-auth, silently restores the persisted
  /// session first so there is a grant to revoke. Best-effort: logged, never
  /// fatal.
  Future<void> _revokeGoogle({required bool alreadyAuthenticated}) async {
    try {
      if (_googleAuthorizationRevoker != null) {
        await _googleAuthorizationRevoker();
        return;
      }
      await _ensureGoogleInitialized();
      if (!alreadyAuthenticated) {
        // No UI: restores the last signed-in Google account if one is cached.
        await _google.attemptLightweightAuthentication();
      }
      await _google.disconnect();
    } catch (e) {
      _logger.w('Google authorization revocation failed; continuing with deletion: $e');
    }
  }

  /// Deletes the Firestore `users/{uid}` profile. Tier 1 scope: other
  /// uid-keyed data (trips / gallery / locations) is left for a Tier 2
  /// privileged cascade.
  Future<void> _deleteUserData(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
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

  static const _nonceCharset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';

  /// A cryptographically secure random string for the Apple sign-in nonce.
  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    return List.generate(length, (_) => _nonceCharset[random.nextInt(_nonceCharset.length)]).join();
  }

  String _sha256OfString(String input) => sha256.convert(utf8.encode(input)).toString();
}
