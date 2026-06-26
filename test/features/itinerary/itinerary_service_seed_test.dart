// Headless tests for the FEAT-006 seed path (no Firebase / GUI).
//
// They verify `ItineraryService.seedItinerary` now pre-fills a freshly created
// trip with the bundled Tokyo demo content (so Home is populated instead of
// blank), that the written keys round-trip back through `watchItinerary`, and
// that the seed stays idempotent and never clobbers an existing document.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late ItineraryService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ItineraryService(firestore: firestore);
  });

  group('ItineraryService.seedItinerary', () {
    test('seeds the Tokyo demo daily_plans and keeps trip-specific invitees', () async {
      await service.seedItinerary('trip-1', ['user-1', 'user-2']);

      final doc = await firestore.collection('itineraries').doc('trip-1').get();
      expect(doc.exists, isTrue);

      final data = doc.data()!;
      expect(data['invitees'], ['user-1', 'user-2']);

      final dailyPlans = data['daily_plans'] as List<dynamic>;
      expect(dailyPlans, isNotEmpty);
      final firstDay = dailyPlans.first as Map<String, dynamic>;
      expect(firstDay['title'], 'SkyTree Day');
      expect(firstDay['location'], 'Tokyo');
    });

    test('seeded document round-trips through watchItinerary', () async {
      await service.seedItinerary('trip-1', ['user-1']);

      final itinerary = await service.watchItinerary('trip-1').firstWhere((it) => it != null);

      expect(itinerary!.id, 'trip-1');
      expect(itinerary.invitees, ['user-1']);
      expect(itinerary.dailyPlans, isNotEmpty);
      expect(itinerary.dailyPlans.first.title, 'SkyTree Day');
      expect(itinerary.dailyPlans.first.plan.locations.first.name, 'Tsukiji Fish Market');
    });

    test('is idempotent and never clobbers an existing document', () async {
      await firestore.collection('itineraries').doc('trip-1').set({
        'invitees': ['real-user'],
        'daily_plans': <dynamic>[],
        'pins': <dynamic>[],
        'last_updated': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
      });

      await service.seedItinerary('trip-1', ['someone-else']);

      final data = (await firestore.collection('itineraries').doc('trip-1').get()).data()!;
      expect(data['invitees'], ['real-user']);
      expect(data['daily_plans'], isEmpty);
    });
  });
}
