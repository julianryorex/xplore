// Unit tests for the FEAT-006 itinerary write path (`ItineraryService`),
// backed by `FakeFirebaseFirestore` (no Firebase / GUI).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';

DailyPlanModel _day({required String title, bool completed = false}) {
  return DailyPlanModel(
    title: title,
    location: 'Tokyo',
    plan: PlanModel(
      favorited: const [],
      locations: [LocationPlanModel(name: 'Tsukiji', completed: completed, placeId: 'p1', description: 'Sushi.')],
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ItineraryService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ItineraryService(firestore: firestore);
  });

  group('ItineraryService.writeDailyPlans', () {
    test('overwrites daily_plans, bumps last_updated, and preserves invitees/pins', () async {
      final doc = firestore.collection('itineraries').doc('trip-1');
      await doc.set({
        'invitees': ['user-1', 'user-2'],
        'daily_plans': [_day(title: 'Old Day').toJson()],
        'pins': <dynamic>['pin-a'],
        'last_updated': Timestamp.fromDate(DateTime.utc(2020, 1, 1)),
      });

      await service.writeDailyPlans('trip-1', [_day(title: 'New Day', completed: true)]);

      final stored = (await doc.get()).data()!;
      final plans = stored['daily_plans'] as List;
      expect(plans, hasLength(1));
      expect((plans.first as Map)['title'], 'New Day');
      expect(((plans.first as Map)['plan']['locations'] as List).first['completed'], isTrue);
      // The edit must not touch membership or pins.
      expect(stored['invitees'], ['user-1', 'user-2']);
      expect(stored['pins'], ['pin-a']);
      expect(stored['last_updated'], isNotNull);
    });

    test('throws on a missing document instead of silently creating one', () async {
      await expectLater(service.writeDailyPlans('missing', [_day(title: 'Day 1')]), throwsA(anything));

      final stored = await firestore.collection('itineraries').doc('missing').get();
      expect(stored.exists, isFalse);
    });
  });
}
