import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';

/// One-line summary of the active trip for the agent screen, e.g.
/// "Tokyo is 12 days out. 5 of your 7 days are still open." [overview] is the
/// active trip's overview when [tripState] is loaded. Returns null while trips
/// are loading or failed to load, so a user with trips is never told to create
/// one. Pass [itineraryLoaded] false while the itinerary is unknown so the line
/// never claims days are open or planned.
String? agentStatusLine(TripState tripState, TripOverview? overview, {bool itineraryLoaded = true}) {
  return switch (tripState) {
    TripEmpty() => 'Create a trip to start planning.',
    TripLoaded() when overview != null => _tripLine(overview, itineraryLoaded: itineraryLoaded),
    _ => null,
  };
}

String _tripLine(TripOverview overview, {required bool itineraryLoaded}) {
  final when = _timingSentence(overview);
  if (overview.timing == TripTiming.past || !itineraryLoaded) {
    return when;
  }
  return '$when ${_planningSentence(overview)}';
}

String _timingSentence(TripOverview overview) {
  final place = _placeName(overview);
  return switch (overview.timing) {
    TripTiming.upcoming => overview.daysToGo == 1 ? '$place is tomorrow.' : '$place is ${overview.daysToGo} days out.',
    TripTiming.ongoing => _ongoingSentence(overview, place),
    TripTiming.past => '$place has wrapped up.',
    TripTiming.undated => '$place has no dates yet.',
  };
}

String _ongoingSentence(TripOverview overview, String place) {
  final length = overview.lengthInDays;
  final day = overview.currentDayNumber;
  return length == null ? 'You’re on day $day in $place.' : 'You’re on day $day of $length in $place.';
}

String _planningSentence(TripOverview overview) {
  final length = overview.lengthInDays;
  final open = overview.openDays;
  if (length == null || overview.plannedDays == 0) {
    return 'Nothing is planned yet.';
  }
  if (open == 0) {
    return length == 1 ? 'Your day is planned.' : 'Every day has a plan.';
  }
  return open == 1 ? '1 of your $length days is still open.' : '$open of your $length days are still open.';
}

String _placeName(TripOverview overview) => overview.trip.headline ?? overview.trip.title;
