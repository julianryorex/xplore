import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_plan.dart';

/// Builds the placeholder day-by-day plan for [draft] from hardcoded catalog
/// themes (no network). Each stop gets one day per night and the last stop one
/// more for departure, so a trip has total nights + 1 days. Days carry no stops
/// so the home keeps reporting them as unplanned.
TripPlan buildStubPlan(TripDraft draft, {PlaceCatalog catalog = placeCatalog}) {
  final days = <DailyPlanModel>[];
  final stopPlans = <StopPlan>[];

  for (var stopIndex = 0; stopIndex < draft.stops.length; stopIndex++) {
    final stop = draft.stops[stopIndex];
    final isLast = stopIndex == draft.stops.length - 1;
    final dayCount = stop.nights + (isLast ? 1 : 0);
    final themes = catalog.byId(stop.id)?.dayThemes ?? const <String>[];

    final dayIndexes = <int>[];
    for (var dayOfStay = 0; dayOfStay < dayCount; dayOfStay++) {
      dayIndexes.add(days.length);
      days.add(
        DailyPlanModel(
          title: themes.isEmpty ? 'Exploring ${stop.name}' : themes[dayOfStay % themes.length],
          location: stop.name,
          plan: const PlanModel(favorited: <String>[], locations: <LocationPlanModel>[]),
        ),
      );
    }

    stopPlans.add(
      StopPlan(
        stop: stop,
        stopIndex: stopIndex,
        dayIndexes: dayIndexes,
        nights: stop.nights,
        stay: draft.stayRangeFor(stopIndex),
      ),
    );
  }

  return TripPlan(days: days, stops: stopPlans);
}
