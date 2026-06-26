import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xplore/constants/constants.dart';
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

  /// Writes a starter itinerary for [tripId] when none exists yet, pre-filled
  /// with the bundled Tokyo demo content so a freshly created trip lands on a
  /// populated Home instead of a blank itinerary.
  ///
  /// Idempotent: returns early if the document is already present so a
  /// create-time seed and a lazy read-time seed never clobber real data.
  ///
  /// [invitees] are always the trip's own [memberIds] and [last_updated] is a
  /// fresh server timestamp; only `daily_plans`/`pins` come from the demo. If
  /// the demo asset is missing or malformed the seed falls back to empty
  /// arrays so trip creation never fails.
  Future<void> seedItinerary(String tripId, List<String> memberIds) async {
    final doc = _itineraries.doc(tripId);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    final seed = await _loadDemoSeed();
    await doc.set(<String, dynamic>{
      'invitees': memberIds,
      'daily_plans': seed.dailyPlans,
      'pins': seed.pins,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Reads the bundled Tokyo demo's `daily_plans`/`pins` (the same asset and
  /// keys that [ItineraryModel.fromJson] parses back) for use as seed content.
  Future<({List<dynamic> dailyPlans, List<dynamic> pins})> _loadDemoSeed() async {
    try {
      final raw = await rootBundle.loadString('assets/demo/itinerary.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final itineraries = decoded['itineraries'] as List<dynamic>;
      final entry =
          itineraries.firstWhere((el) => (el as Map<String, dynamic>).containsKey(itineraryId)) as Map<String, dynamic>;
      final itinerary = entry[itineraryId] as Map<String, dynamic>;
      return (
        dailyPlans: (itinerary['daily_plans'] as List<dynamic>?) ?? const <dynamic>[],
        pins: (itinerary['pins'] as List<dynamic>?) ?? const <dynamic>[],
      );
    } catch (_) {
      return (dailyPlans: const <dynamic>[], pins: const <dynamic>[]);
    }
  }
}
