import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Firestore metadata layer for the shared trip gallery (FEAT-011).
///
/// One document per photo at `galleries/{tripId}/images/{imageId}` carrying a
/// small inline thumbnail, so every member's grid paints straight from a single
/// live listener. The full-res original stays in Storage at `storagePath`.
class GalleryService {
  GalleryService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: AuthService.appDatabaseId);

  final FirebaseFirestore _firestore;
  final Logger _logger = createLogger('GalleryService');

  CollectionReference<Map<String, dynamic>> _images(String tripId) =>
      _firestore.collection('galleries').doc(tripId).collection('images');

  /// Live list of [tripId]'s photos, oldest upload first.
  ///
  /// Malformed documents are logged and skipped so one bad doc never breaks the stream.
  Stream<List<ImageModel>> watchTripImages(String tripId) {
    return _images(tripId).orderBy('uploadedAt').snapshots().map((snapshot) {
      final images = <ImageModel>[];
      for (final doc in snapshot.docs) {
        final image = _imageFromDoc(doc);
        if (image != null) images.add(image);
      }
      return images;
    });
  }

  /// Records an uploaded photo's metadata for [tripId].
  ///
  /// Idempotent: an upload retry for an already-recorded [imageId] is a no-op,
  /// because the security rules forbid updating an existing image doc.
  Future<void> writeImageMetadata({
    required String tripId,
    required String imageId,
    required String uploaderUid,
    required DateTime createdAt,
    required String fullUrl,
    required String storagePath,
    required Uint8List thumb,
    String? uploaderName,
  }) async {
    final doc = _images(tripId).doc(imageId);
    // A transaction (not get-then-set) so two concurrent retries can't both
    // attempt a create; the loser re-reads, sees the doc and stops.
    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) return;

      transaction.set(doc, <String, dynamic>{
        'uploaderUid': uploaderUid,
        'uploaderName': ?uploaderName,
        'createdAt': Timestamp.fromDate(createdAt),
        'uploadedAt': FieldValue.serverTimestamp(),
        'fullUrl': fullUrl,
        'storagePath': storagePath,
        'thumb': Blob(thumb),
      });
    });
  }

  // `uploadedAt` is deliberately not read: it is only the ordering key, and it
  // is null on a just-written doc until the server timestamp resolves.
  ImageModel? _imageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final thumb = data['thumb'];
    final fullUrl = data['fullUrl'];
    final uploaderUid = data['uploaderUid'];
    final uploaderName = data['uploaderName'];

    if (createdAt is! Timestamp || thumb is! Blob || fullUrl is! String || uploaderUid is! String) {
      _logger.w('Skipping malformed gallery image doc ${doc.reference.path}');
      return null;
    }

    return ImageModel(
      id: doc.id,
      createdAt: createdAt.toDate(),
      lowResImage: thumb.bytes,
      isUploading: EUploadStatus.complete,
      downloadUrl: fullUrl,
      uploaderUid: uploaderUid,
      uploaderName: uploaderName is String ? uploaderName : null,
    );
  }
}
