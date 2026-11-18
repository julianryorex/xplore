import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

void main() {
  final stops = [placeCatalog.byId('tokyo')!.toStop(nights: 4), placeCatalog.byId('kyoto')!.toStop(nights: 3)];

  group('TripModel JSON', () {
    test('a document written before stops existed still parses, with no stops', () {
      final trip = TripModel.fromJson({
        'id': 't1',
        'title': 'Lisbon getaway',
        'memberIds': ['u1'],
        'createdBy': 'u1',
        'destination': 'Lisbon',
      });

      expect(trip.stops, isEmpty);
      expect(trip.headline, 'Lisbon');
    });

    test('stops round-trip and drive the headline', () {
      final trip = TripModel(
        id: 't1',
        title: 'Japan with friends',
        memberIds: const ['u1'],
        createdBy: 'u1',
        destination: 'Tokyo, Kyoto',
        stops: stops,
      );
      final parsed = TripModel.fromJson({...trip.toJson(), 'id': 't1'});

      expect(parsed.stops, stops);
      expect(parsed.headline, 'Japan');
    });

    test('headline is null without stops or destination', () {
      const trip = TripModel(id: 't1', title: 'Trip', memberIds: ['u1'], createdBy: 'u1', destination: '  ');
      expect(trip.headline, isNull);
    });
  });

  test('TripService persists stops on the trip document', () async {
    final firestore = FakeFirebaseFirestore();
    final service = TripService(firestore: firestore);

    final created = await service.createTrip('Japan', 'u1', destination: 'Tokyo, Kyoto', stops: stops);
    final stored = await service.fetchTrip(created.id).first;

    expect(stored!.stops, stops);
    expect(stored.destination, 'Tokyo, Kyoto');
  });
}
