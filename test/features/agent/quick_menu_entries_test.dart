import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/agent/models/quick_menu_entries.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

final _trip = TripModel(
  id: 't1',
  title: 'Tokyo',
  memberIds: const ['me'],
  createdBy: 'me',
  startDate: DateTime(2026, 4, 3),
  endDate: DateTime(2026, 4, 5),
);

DailyPlanModel _day({required int stops}) => DailyPlanModel(
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

LoadedItineraryState _itinerary(List<DailyPlanModel> days) => LoadedItineraryState(
  itinerary: ItineraryModel(id: 'i1', invitees: const [], dailyPlans: days, pins: const []),
);

void main() {
  final loadedTrip = TripState.loaded(active: _trip, all: [_trip]);

  test('suggests planning the first day that has no stops', () {
    final entries = QuickMenuEntries.from(
      trip: loadedTrip,
      itinerary: _itinerary([_day(stops: 2), _day(stops: 0), _day(stops: 0)]),
    );

    expect(entries.planDayPrompt, 'Plan Apr 4 for me');
  });

  test('offers no suggestion once every day has stops', () {
    final entries = QuickMenuEntries.from(trip: loadedTrip, itinerary: _itinerary([_day(stops: 1), _day(stops: 3)]));

    expect(entries.planDayPrompt, isNull);
  });

  test('offers no suggestion until both the trip and its itinerary are loaded', () {
    final emptyDays = _itinerary([_day(stops: 0)]);

    expect(QuickMenuEntries.from(trip: const TripState.loading(), itinerary: emptyDays).planDayPrompt, isNull);
    expect(QuickMenuEntries.from(trip: loadedTrip, itinerary: const LoadingItineraryState()).planDayPrompt, isNull);
  });
}
