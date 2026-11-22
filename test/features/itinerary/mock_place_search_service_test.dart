import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/stop_display.dart';
import 'package:xplore/features/itinerary/services/mock_place_search_service.dart';

void main() {
  const search = MockPlaceSearchService(latency: Duration.zero);

  test('matches ignore case and accents', () async {
    final results = await search.search('senso-ji');

    expect(results.first.name, 'Sensō-ji');
  });

  test('places near the day come before better matches elsewhere', () async {
    final results = await search.search('market', near: 'Kyoto');

    expect(results.first.city, 'Kyoto');
    expect(results.map((place) => place.city).toSet().length, greaterThan(1));
  });

  test('an empty query suggests only places around the day', () async {
    final results = await search.search('', near: 'Tokyo');

    expect(results, isNotEmpty);
    expect(results.every((place) => place.city == 'Tokyo'), isTrue);
  });

  test('a query nothing matches returns no places', () async {
    expect(await search.search('zzzz', near: 'Tokyo'), isEmpty);
  });

  test('every mock place has the details a stop saves', () async {
    for (final place in search.places) {
      expect(place.id, startsWith('mock:'), reason: place.name);
      expect(place.category, isNotEmpty, reason: place.name);
      expect(place.neighbourhood, isNotEmpty, reason: place.name);
      expect(place.address, isNotEmpty, reason: place.name);
    }
    expect(search.places.map((place) => place.id).toSet(), hasLength(search.places.length));
  });

  test('a picked place becomes a stop carrying its details', () async {
    final place = (await search.search('Sumida Hokusai')).first;

    final stop = stopFromPlace(place, note: 'Closed on Mondays.');

    expect(stop.isCustom, isFalse);
    expect(stop.placeId, place.id);
    expect(stop.description, 'Closed on Mondays.');
    expect(stopSubtitle(stop, withHours: true), 'Art museum · Ryōgoku · Open until 17:30');
  });

  test('custom stops and stops without details get an honest subtitle', () {
    expect(stopSubtitle(customStop(' Back to the hotel lobby ')), 'Custom stop · No map pin');
    expect(customStop(' Back to the hotel lobby ').name, 'Back to the hotel lobby');
    expect(openingHoursLabel('Open 24 hours'), 'Open 24 hours');
    expect(openingHoursLabel(''), isNull);
  });
}
