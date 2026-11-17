import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/agent/models/agent_status_line.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

TripModel _trip({DateTime? start, DateTime? end, String? destination = 'Tokyo'}) => TripModel(
  id: 't1',
  title: 'Tokyo with the crew',
  memberIds: const ['me'],
  createdBy: 'me',
  startDate: start,
  endDate: end,
  destination: destination,
);

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

/// The status line for [overview] as the loaded active trip.
String? _lineFor(TripOverview overview, {bool itineraryLoaded = true}) => agentStatusLine(
  TripState.loaded(active: overview.trip, all: [overview.trip]),
  overview,
  itineraryLoaded: itineraryLoaded,
);

void main() {
  final start = DateTime(2026, 4, 3);
  final end = DateTime(2026, 4, 9);
  final week = [_day(stops: 3), _day(stops: 2), for (var i = 0; i < 5; i++) _day()];

  test('counts down to an upcoming trip and its open days', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: week,
      now: DateTime(2026, 3, 22),
    );

    expect(_lineFor(overview), 'Tokyo is 12 days out. 5 of your 7 days are still open.');
  });

  test('reports the current day of an ongoing, fully planned trip', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: [for (var i = 0; i < 7; i++) _day(stops: 1)],
      now: DateTime(2026, 4, 5),
    );

    expect(_lineFor(overview), 'You’re on day 3 of 7 in Tokyo. Every day has a plan.');
  });

  test('says a past trip has wrapped up without commenting on its plan', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: week,
      now: DateTime(2026, 5, 1),
    );

    expect(_lineFor(overview), 'Tokyo has wrapped up.');
  });

  test('falls back to the title for an undated trip with nothing planned', () {
    final overview = TripOverview(trip: _trip(destination: ' '));

    expect(_lineFor(overview), 'Tokyo with the crew has no dates yet. Nothing is planned yet.');
  });

  test('makes no planning claim while the itinerary has not loaded', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      now: DateTime(2026, 4, 2),
    );

    expect(_lineFor(overview, itineraryLoaded: false), 'Tokyo is tomorrow.');
  });

  test('says when only one day is still open', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: end),
      dailyPlans: [for (var i = 0; i < 6; i++) _day(stops: 1), _day()],
      now: DateTime(2026, 3, 22),
    );

    expect(_lineFor(overview), 'Tokyo is 12 days out. 1 of your 7 days is still open.');
  });

  test('uses the singular wording for a fully planned one-day trip', () {
    final overview = TripOverview(
      trip: _trip(start: start, end: start),
      dailyPlans: [_day(stops: 2)],
      now: DateTime(2026, 3, 22),
    );

    expect(_lineFor(overview), 'Tokyo is 12 days out. Your day is planned.');
  });

  test('prompts to create a trip only when the user has none', () {
    expect(agentStatusLine(const TripState.empty(), null), 'Create a trip to start planning.');
  });

  test('stays silent while trips are loading or failed to load', () {
    expect(agentStatusLine(const TripState.loading(), null), isNull);
    expect(agentStatusLine(const TripState.error('offline'), null), isNull);
  });
}
