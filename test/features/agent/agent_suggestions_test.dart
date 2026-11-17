import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/agent/models/agent_suggestions.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

TripModel _trip({DateTime? start, DateTime? end}) =>
    TripModel(id: 't1', title: 'Tokyo', memberIds: const ['me'], createdBy: 'me', startDate: start, endDate: end);

DailyPlanModel _day(String title, {int stops = 0}) => DailyPlanModel(
  title: title,
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
  final beforeTrip = DateTime(2026, 3, 22);

  test('suggests the first empty day, a thin day, the open days and moving a stop', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: [
        _day('Asakusa', stops: 4),
        _day('Shinjuku Day', stops: 2),
        _day('Day 3'),
        for (var i = 0; i < 4; i++) _day('Free'),
      ],
      now: beforeTrip,
    );

    expect(agentSuggestions(overview), [
      'Plan Apr 5 for me',
      'Fill out Shinjuku Day',
      'Draft all 5 open days',
      'Move a stop to another day',
    ]);
  });

  test('offers only moving stops once every day is well planned', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: [for (var i = 0; i < 7; i++) _day('Day', stops: 3)],
      now: beforeTrip,
    );

    expect(agentSuggestions(overview), ['Move a stop to another day']);
  });

  test('labels days by position for an undated trip and skips the draft-all prompt for one open day', () {
    final overview = TripOverview(trip: _trip(), dailyPlans: [_day('Arrival')]);

    expect(agentSuggestions(overview), ['Plan Day 1 for me']);
  });

  test('suggests nothing without itinerary days or after the trip', () {
    final noDays = TripOverview(
      trip: _trip(start: start, end: end),
      now: beforeTrip,
    );
    final past = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: [_day('Day'), _day('Day', stops: 1)],
      now: DateTime(2026, 5, 1),
    );

    expect(agentSuggestions(noDays), isEmpty);
    expect(agentSuggestions(past), isEmpty);
  });
}
