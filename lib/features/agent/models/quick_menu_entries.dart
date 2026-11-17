import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';

/// Which optional entries the agent quick menu shows for the current trip.
///
/// "Plan a new trip" and "Ask anything" are always offered; only the
/// day-planning suggestion depends on state, so that is all this carries.
class QuickMenuEntries {
  const QuickMenuEntries({this.planDayPrompt});

  /// Derives the entries from the active trip and its itinerary. The day
  /// suggestion appears only when a loaded itinerary still has a day without stops.
  factory QuickMenuEntries.from({required TripState trip, required ItineraryStates itinerary}) {
    if (trip is! TripLoaded || itinerary is! LoadedItineraryState) {
      return const QuickMenuEntries();
    }
    final overview = TripOverview(trip: trip.active, dailyPlans: itinerary.itinerary.dailyPlans);
    final emptyDay = overview.firstEmptyDayIndex;
    if (emptyDay == null) {
      return const QuickMenuEntries();
    }
    return QuickMenuEntries(planDayPrompt: 'Plan ${overview.dayLabel(emptyDay)} for me');
  }

  /// Label of the "Plan Apr 5 for me" style row, also sent to the agent as its prompt.
  final String? planDayPrompt;
}
