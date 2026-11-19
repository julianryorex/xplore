import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';

TripStop _stop(String id, {int nights = 1}) => placeCatalog.byId(id)!.toStop(nights: nights);

TripDraft _exact(List<TripStop> stops, DateTime start, DateTime end) =>
    TripDraft(stops: stops, datesAreFlexible: false, startDate: start, endDate: end);

void main() {
  group('splitNightsEvenly', () {
    test('gives the remainder to the earliest stops', () {
      expect(splitNightsEvenly(10, 3), [4, 3, 3]);
      expect(splitNightsEvenly(9, 3), [3, 3, 3]);
    });

    test('a single stop takes every night, including none', () {
      expect(splitNightsEvenly(7, 1), [7]);
      expect(splitNightsEvenly(0, 1), [0]);
    });

    test('falls back to one night each when there are too few nights', () {
      expect(splitNightsEvenly(2, 4), [1, 1, 1, 1]);
    });

    test('returns nothing for no stops', () {
      expect(splitNightsEvenly(5, 0), isEmpty);
    });
  });

  group('nightsAllocation with exact dates', () {
    final start = DateTime(2026, 4, 1);
    final end = DateTime(2026, 4, 11); // 10 nights

    test('is valid only when every stop has a night and the sum matches', () {
      final draft = _exact([_stop('tokyo', nights: 6), _stop('kyoto', nights: 4)], start, end);
      expect(draft.nightsAllocation, const NightsAllocation(assigned: 10, target: 10, stopCount: 2));
      expect(draft.isNightsAllocationValid, isTrue);
    });

    test('reports unassigned and overassigned nights', () {
      final under = _exact([_stop('tokyo', nights: 5), _stop('kyoto', nights: 4)], start, end);
      expect(under.nightsAllocation.issue, NightsIssue.unassigned);
      expect(under.nightsAllocation.assigned, 9);
      expect(under.nightsAllocation.target, 10);

      final over = _exact([_stop('tokyo', nights: 7), _stop('kyoto', nights: 4)], start, end);
      expect(over.nightsAllocation.issue, NightsIssue.overassigned);
    });

    test('reports fewer nights than stops', () {
      final stops = [_stop('tokyo'), _stop('hakone'), _stop('kyoto'), _stop('osaka')];
      final draft = _exact(stops, start, DateTime(2026, 4, 4)); // 3 nights for 4 places
      expect(draft.nightsAllocation.issue, NightsIssue.fewerNightsThanStops);
      expect(draft.nightsAllocation.stopCount, 4);
    });

    test('a single-place same-day trip is valid with zero nights and lasts one day', () {
      final draft = _exact([_stop('kamakura', nights: 0)], start, start);
      expect(draft.isNightsAllocationValid, isTrue);
      expect(draft.durationDays, 1);
      expect(draft.stayRangeFor(0), StayRange(start: start, end: start));
    });

    test('flags a stop without nights', () {
      final draft = _exact([_stop('tokyo', nights: 10), _stop('kyoto', nights: 0)], start, end);
      expect(draft.nightsAllocation.issue, NightsIssue.stopWithoutNights);
    });

    test('flags trips longer than the maximum', () {
      final draft = _exact([_stop('tokyo', nights: 70)], start, start.add(const Duration(days: 70)));
      expect(draft.nightsAllocation.issue, NightsIssue.tooLong);
    });

    test('totalNights and durationDays follow the dates', () {
      final draft = _exact([_stop('tokyo', nights: 3)], start, end);
      expect(draft.totalNights, 10);
      expect(draft.durationDays, 11);
    });
  });

  group('nightsAllocation with flexible dates', () {
    test('the stops nights are the trip length', () {
      final draft = TripDraft(stops: [_stop('lisbon', nights: 3), _stop('porto', nights: 2)]);
      expect(draft.nightsAllocation, const NightsAllocation(assigned: 5, target: null, stopCount: 2));
      expect(draft.totalNights, 5);
      expect(draft.durationDays, 6);
      expect(draft.stayRangeFor(0), isNull);
    });

    test('no stops is not a valid allocation', () {
      expect(const TripDraft().nightsAllocation.issue, NightsIssue.noStops);
    });
  });

  test('stayRangeFor chains each stay onto the previous one', () {
    final draft = _exact(
      [_stop('tokyo', nights: 4), _stop('hakone', nights: 2), _stop('kyoto', nights: 4)],
      DateTime(2026, 3, 28),
      DateTime(2026, 4, 7),
    );
    expect(draft.stayRangeFor(0), StayRange(start: DateTime(2026, 3, 28), end: DateTime(2026, 4, 1)));
    expect(draft.stayRangeFor(1), StayRange(start: DateTime(2026, 4, 1), end: DateTime(2026, 4, 3)));
    expect(draft.stayRangeFor(2), StayRange(start: DateTime(2026, 4, 3), end: DateTime(2026, 4, 7)));
    expect(draft.stayRangeFor(3), isNull);
  });

  group('headline', () {
    test('uses the place, the shared country, or the first place plus a count', () {
      expect(TripDraft(stops: [_stop('lisbon')]).headline, 'Lisbon');
      expect(TripDraft(stops: [_stop('tokyo'), _stop('hakone'), _stop('kyoto'), _stop('osaka')]).headline, 'Japan');
      expect(TripDraft(stops: [_stop('paris'), _stop('rome'), _stop('venice')]).headline, 'Paris + 2 more');
      expect(const TripDraft().headline, isEmpty);
    });
  });

  group('suggestedTitle', () {
    test('adapts the place to the group kind', () {
      final japan = [_stop('tokyo'), _stop('kyoto')];
      expect(TripDraft(stops: japan, groupKind: TripGroupKind.friends).suggestedTitle, 'Japan with friends');
      expect(TripDraft(stops: [_stop('tokyo')], groupKind: TripGroupKind.couple).suggestedTitle, 'Tokyo for two');
      expect(TripDraft(stops: [_stop('lisbon')]).suggestedTitle, 'Solo in Lisbon');
      expect(TripDraft(stops: [_stop('bali')], groupKind: TripGroupKind.family).suggestedTitle, 'Family trip to Bali');
    });

    test('names up to two countries and falls back without places', () {
      expect(TripDraft(stops: [_stop('paris'), _stop('rome')]).suggestedTitle, 'Solo in France and Italy');
      expect(const TripDraft().suggestedTitle, 'My trip');
    });

    test('a typed title wins over the suggestion', () {
      final draft = TripDraft(stops: [_stop('tokyo')], title: '  Cherry blossoms  ');
      expect(draft.effectiveTitle, 'Cherry blossoms');
      expect(draft.copyWith(title: ' ').effectiveTitle, 'Solo in Tokyo');
    });
  });

  test('destination joins the stop names for legacy readers', () {
    expect(TripDraft(stops: [_stop('tokyo'), _stop('kyoto')]).destination, 'Tokyo, Kyoto');
  });
}
