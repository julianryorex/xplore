import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

/// Firestore-backed read path for trip itineraries.
///
/// One document per trip at `itineraries/{tripId}` with the `daily_plans` array
/// embedded (mirrors `assets/demo/itinerary.json`), so a live read is a single
/// document listener — no composite index required.
class ItineraryService {
  ItineraryService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: AuthService.appDatabaseId);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itineraries => _firestore.collection('itineraries');

  /// Real-time itinerary for [tripId]; emits `null` while the document is absent.
  Stream<ItineraryModel?> watchItinerary(String tripId) {
    return _itineraries.doc(tripId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return ItineraryModel.fromJson({...data, 'id': snapshot.id});
    });
  }

  /// Writes a minimal starter itinerary for [tripId] when none exists yet.
  ///
  /// Idempotent: returns early if the document is already present so a
  /// create-time seed and a lazy read-time seed never clobber real data.
  Future<void> seedItinerary(String tripId, List<String> memberIds) async {
    final doc = _itineraries.doc(tripId);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    await doc.set(<String, dynamic>{
      'invitees': memberIds,
      'daily_plans': <dynamic>[],
      'pins': <dynamic>[],
      'last_updated': FieldValue.serverTimestamp(),
    });
  }
}
