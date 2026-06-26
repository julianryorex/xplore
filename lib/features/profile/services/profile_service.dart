import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/profile/models/profile_models.dart';

/// Read/write access to the cloud profile: the Firestore `users/{uid}` document
/// and the avatar object in Storage (FEAT-015).
///
/// A plain service (no Flutter / bloc imports), composed into [ProfileCubit] via
/// constructor injection. Handle *claiming* lives in [AuthService] for the
/// auto-generated handle; the user-driven claim/availability API will move here
/// alongside the onboarding handle-picker (FEAT-005).
class ProfileService {
  ProfileService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: AuthService.appDatabaseId),
      // Public param name can't be an initializing formal for the private field.
      // ignore: prefer_initializing_formals
      _storage = storage;

  final FirebaseFirestore _firestore;
  // Lazy so a Firestore-only test (injecting a fake firestore) can construct the
  // service without touching Firebase Storage.
  FirebaseStorage? _storage;
  FirebaseStorage get _storageInstance => _storage ??= FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// Real-time profile for [uid]; emits `null` while the document is absent.
  Stream<UserProfile?> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return UserProfile.fromJson({...data, 'uid': snapshot.id});
    });
  }

  /// Uploads the source avatar to `avatars/{uid}/avatar` and returns its
  /// download URL.
  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    final ref = _storageInstance.ref().child('avatars/$uid/avatar');
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return task.ref.getDownloadURL();
  }

  /// Persists the avatar [url] onto `users/{uid}`.
  Future<void> setPhotoUrl(String uid, String url) async {
    await _users.doc(uid).set({'photoUrl': url}, SetOptions(merge: true));
  }
}
