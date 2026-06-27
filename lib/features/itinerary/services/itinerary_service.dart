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

  /// Writes a starter itinerary for [tripId] when none exists yet, optionally
  /// pre-populated with a generated [dailyPlans] skeleton (see
  /// [ItineraryGenerator]). When [dailyPlans] is empty this is the original
  /// empty seed.
  ///
  /// Idempotent: returns early if the document is already present so a
  /// create-time seed and a lazy read-time seed never clobber real data.
  Future<void> seedItinerary(
    String tripId,
    List<String> memberIds, {
    List<DailyPlanModel> dailyPlans = const <DailyPlanModel>[],
  }) async {
    final doc = _itineraries.doc(tripId);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    await doc.set(<String, dynamic>{
      'invitees': memberIds,
      'daily_plans': dailyPlans.map((plan) => plan.toJson()).toList(),
      'pins': <dynamic>[],
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Overwrites the embedded `daily_plans` array for [tripId] and bumps
  /// `last_updated`. Every itinerary edit (toggle completion, add/edit/remove a
  /// day or stop) funnels through here as a whole-array write — the doc is small
  /// and low-contention, so last-write-wins is acceptable (see FEAT-006 plan).
  ///
  /// Uses `update` (not `set`), so a missing document throws rather than being
  /// silently re-created without its `invitees`/`pins`; the seed path is the
  /// only creator.
  Future<void> writeDailyPlans(String tripId, List<DailyPlanModel> dailyPlans) async {
    await _itineraries.doc(tripId).update(<String, dynamic>{
      'daily_plans': dailyPlans.map((plan) => plan.toJson()).toList(),
      'last_updated': FieldValue.serverTimestamp(),
    });
  }
}
