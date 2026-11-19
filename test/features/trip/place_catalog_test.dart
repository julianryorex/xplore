import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';

List<String> _ids(List<CatalogPlace> places) => places.map((place) => place.id).toList();

void main() {
  const catalog = placeCatalog;

  test('catalog ids are unique and every place has 3-5 day themes', () {
    final ids = _ids(catalog.places);
    expect(ids.toSet(), hasLength(ids.length));
    for (final place in catalog.places) {
      expect(place.dayThemes.length, inInclusiveRange(3, 5), reason: place.id);
    }
    expect(catalog.popularIds.every((id) => catalog.byId(id) != null), isTrue);
  });

  group('search', () {
    test('an empty query returns the popular list without excluded ids', () {
      expect(_ids(catalog.search('  ')), catalog.popularIds);
      expect(_ids(catalog.search('', exclude: ['tokyo'])), isNot(contains('tokyo')));
    });

    test('ranks name prefix, then name contains, then country matches', () {
      final ids = _ids(catalog.search('na'));
      // Prefix: Nara, Naples. Contains: e.g. Kanazawa, Barcelona. No country contains "na".
      expect(ids.indexOf('nara'), lessThan(ids.indexOf('kanazawa')));
      expect(ids.indexOf('naples'), lessThan(ids.indexOf('barcelona')));

      final japan = _ids(catalog.search('japan'));
      expect(japan, containsAll(['tokyo', 'kyoto', 'nikko']));
      expect(japan.first, 'tokyo');
    });

    test('a name match ranks above a country match', () {
      // "Lagos" starts with "la"; Thailand's places only match by country.
      final ids = _ids(catalog.search('la'));
      expect(ids.indexOf('lagos'), lessThan(ids.indexOf('bangkok')));
    });

    test('is case- and accent-insensitive', () {
      expect(_ids(catalog.search('REYKJAVIK')), ['reykjavik']);
      expect(_ids(catalog.search('cancun')), ['cancun']);
      expect(_ids(catalog.search('Reykjavík')), ['reykjavik']);
    });

    test('leaves out excluded ids', () {
      expect(_ids(catalog.search('kyoto', exclude: ['kyoto'])), isEmpty);
    });
  });

  group('suggestionsFor', () {
    test('is empty without stops', () {
      expect(catalog.suggestionsFor(const []), isEmpty);
    });

    test('suggests same-country places nearest the last stop, excluding added ones', () {
      final stops = [catalog.byId('tokyo')!.toStop(), catalog.byId('kyoto')!.toStop()];
      final ids = _ids(catalog.suggestionsFor(stops));

      // Nara and Osaka are both close to Kyoto; Kamakura is far.
      expect(ids, hasLength(3));
      expect(ids.take(2), containsAll(['nara', 'osaka']));
      expect(ids, isNot(contains('tokyo')));
      expect(ids, isNot(contains('kyoto')));
      expect(ids.every((id) => catalog.byId(id)!.country == 'Japan'), isTrue);
    });

    test('respects the limit', () {
      final stops = [catalog.byId('lisbon')!.toStop()];
      expect(catalog.suggestionsFor(stops, limit: 1).single.id, 'sintra');
    });
  });
}
