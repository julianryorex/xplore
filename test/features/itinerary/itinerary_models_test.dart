// Back-compatibility of the itinerary models: documents stored before place
// details and change records existed must still load, and the new fields must
// survive the JSON round trip used for Firestore writes and the Hive cache.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

void main() {
  test('a stop stored before place details existed still loads', () {
    final stop = LocationPlanModel.fromJson({
      'name': 'Tsukiji Fish Market',
      'completed': true,
      'place_id': 'ChIJISz8h9hx5kcRR6Ko1HuQAg4',
      'description': 'Sushi breakfast.',
    });

    expect(stop.name, 'Tsukiji Fish Market');
    expect(stop.completed, isTrue);
    expect(stop.isCustom, isFalse);
    expect(stop.category, isEmpty);
    expect(stop.openingHours, isEmpty);
    expect(stop.lastChange, isNull);
  });

  test('a stop without a place id reads as a custom stop', () {
    expect(LocationPlanModel.fromJson({'name': 'Back to the hotel lobby', 'place_id': ''}).isCustom, isTrue);
    expect(LocationPlanModel.fromJson({'name': 'Back to the hotel lobby'}).isCustom, isTrue);
  });

  test('a day stored without a change record still loads', () {
    final day = DailyPlanModel.fromJson({
      'title': 'SkyTree Day',
      'location': 'Tokyo',
      'plan': {'favorited': <String>[], 'locations': <dynamic>[]},
    });

    expect(day.lastChange, isNull);
  });

  test('place details and the change record survive a JSON round trip', () {
    final stop = LocationPlanModel(
      name: 'Sensō-ji',
      placeId: 'mock:tokyo-sensoji',
      description: 'Meet by the big lantern.',
      category: 'Temple',
      neighbourhood: 'Asakusa',
      address: '2-3-1 Asakusa, Taito City, Tokyo',
      openingHours: '06:00–17:00',
      photoReference: 'photo-ref',
      lastChange: ItineraryChangeModel(
        action: ItineraryChangeAction.edited,
        authorType: ChangeAuthorType.scout,
        at: DateTime.utc(2026, 11, 21, 9),
      ),
    );

    final restored = LocationPlanModel.fromJson(jsonDecode(jsonEncode(stop.toJson())) as Map<String, dynamic>);

    expect(restored, stop);
  });

  test('a change record with values this build does not know still loads', () {
    final change = ItineraryChangeModel.fromJson({
      'action': 'merged',
      'author_type': 'integration',
      'author_id': 'x',
      'at': '2026-11-21T09:00:00.000Z',
    });

    expect(change.action, ItineraryChangeAction.edited);
    expect(change.authorType, ChangeAuthorType.person);
  });
}
