import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

TripModel _trip({DateTime? start, DateTime? end, List<String> members = const ['me']}) =>
    TripModel(id: 't1', title: 'Trip', memberIds: members, createdBy: 'me', startDate: start, endDate: end);

DailyPlanModel _day({int stops = 0}) => DailyPlanModel(
  title: 'Day',
  location: 'Tokyo',
  plan: PlanModel(
    favorited: const [],
    locations: [
      for (var i = 0; i < stops; i++)
        LocationPlanModel(name: 'Stop $i', completed: false, placeId: '', description: ''),
    ],
  ),
);

void main() {
  final start = DateTime(2026, 4, 3);
  final end = DateTime(2026, 4, 9);

  group('TripOverview countdown', () {
    test('counts whole days until an upcoming trip, ignoring time of day', () {
      final overview = TripOverview(
        trip: _trip(start: start, end: end),
        now: DateTime(2026, 3, 22, 23, 59),
      );

      expect(overview.timing, TripTiming.upcoming);
      expect(overview.daysToGo, 12);
      expect(overview.currentDayNumber, isNull);
    });

    test('reports the current day while the trip is under way, including its last day', () {
      final firstDay = TripOverview(
        trip: _trip(start: start, end: end),
        now: DateTime(2026, 4, 3, 8),
      );
      final lastDay = TripOverview(
        trip: _trip(start: start, end: end),
        now: DateTime(2026, 4, 9, 22),
      );

      expect(firstDay.timing, TripTiming.ongoing);
      expect(firstDay.currentDayNumber, 1);
      expect(firstDay.daysToGo, isNull);
      expect(lastDay.currentDayNumber, 7);
    });

    test('is past once the end date has gone by', () {
      final overview = TripOverview(
        trip: _trip(start: start, end: end),
        now: DateTime(2026, 4, 10),
      );

      expect(overview.timing, TripTiming.past);
      expect(overview.daysToGo, isNull);
    });

    test('has no countdown for a trip without dates', () {
      final overview = TripOverview(trip: _trip(), now: DateTime(2026, 4, 1));

      expect(overview.timing, TripTiming.undated);
      expect(overview.daysToGo, isNull);
      expect(overview.dateRangeLabel, isNull);
    });

    // Each pair spans a DST change only in its own region's time zones (EU: Mar 29,
    // US: Mar 8), so together they cover whichever zone the tests run in.
    test('does not drift across a daylight-saving change', () {
      final acrossEuChange = TripOverview(
        trip: _trip(start: DateTime(2026, 4, 3), end: DateTime(2026, 4, 9)),
        now: DateTime(2026, 3, 27),
      );
      final acrossUsChange = TripOverview(
        trip: _trip(start: DateTime(2026, 3, 10), end: DateTime(2026, 3, 12)),
        now: DateTime(2026, 3, 3),
      );

      expect(acrossEuChange.daysToGo, 7);
      expect(acrossUsChange.daysToGo, 7);
    });

    test('treats an end date before the start date as missing', () {
      final overview = TripOverview(
        trip: _trip(start: end, end: start),
        now: DateTime(2026, 4, 9),
      );

      expect(overview.timing, TripTiming.ongoing);
      expect(overview.lengthInDays, isNull);
      expect(overview.dateRangeLabel, isNull);
    });
  });

  group('TripOverview planning progress', () {
    test('counts only days with stops, against the dated trip length', () {
      final overview = TripOverview(
        trip: _trip(start: start, end: end),
        dailyPlans: [_day(stops: 5), _day(stops: 1), _day(), _day(), _day(), _day(), _day()],
      );

      expect(overview.lengthInDays, 7);
      expect(overview.plannedDays, 2);
      expect(overview.openDays, 5);
      expect(overview.firstEmptyDayIndex, 2);
      expect(overview.dayLabel(2), 'Apr 5');
      expect(overview.dateRangeLabel, 'Apr 3 – Apr 9');
    });

    test('ignores itinerary days beyond the dated trip length', () {
      final overview = TripOverview(
        trip: _trip(start: start, end: DateTime(2026, 4, 5)),
        dailyPlans: [for (var i = 0; i < 5; i++) _day(stops: 1)],
      );

      expect(overview.lengthInDays, 3);
      expect(overview.plannedDays, 3);
      expect(overview.openDays, 0);
    });

    test('skips days that have already passed while the trip is under way', () {
      final overview = TripOverview(
        trip: _trip(start: start, end: end),
        dailyPlans: [_day(stops: 5), _day(stops: 1), _day(), _day(stops: 1), _day(), _day(), _day(stops: 2)],
        now: DateTime(2026, 4, 6),
      );

      expect(overview.firstEmptyDayIndex, 4);
      expect(overview.suggestedPlanDayPrompt, 'Plan Apr 7 for me');
      expect(overview.openDays, 2);
    });

    test('falls back to the itinerary length and positional day labels when undated', () {
      final overview = TripOverview(trip: _trip(), dailyPlans: [_day(stops: 2), _day()]);

      expect(overview.lengthInDays, 2);
      expect(overview.firstEmptyDayIndex, 1);
      expect(overview.dayLabel(1), 'Day 2');
    });

    test('has no empty day when every day has a stop, and no length when nothing is known', () {
      expect(TripOverview(trip: _trip(), dailyPlans: [_day(stops: 1)]).firstEmptyDayIndex, isNull);
      expect(TripOverview(trip: _trip()).lengthInDays, isNull);
      expect(TripOverview(trip: _trip()).openDays, 0);
    });
  });
}
