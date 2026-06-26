import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';

/// Produces the day skeleton an itinerary is seeded with when a trip is
/// created. Phase 1 is deterministic ([DeterministicItineraryGenerator]); phase
/// 2 swaps in a Gemini-backed implementation behind the same interface, falling
/// back to the deterministic skeleton on any failure.
abstract class ItineraryGenerator {
  Future<List<DailyPlanModel>> generate(TripDraft draft);
}

/// A no-AI generator: one [DailyPlanModel] per day in the trip's
/// duration/date range, titled "Day N" and anchored to the destination. Stops
/// are intentionally left empty for phase 1 (review is read-only); real stops
/// arrive with the Gemini engine + itinerary CRUD.
class DeterministicItineraryGenerator implements ItineraryGenerator {
  const DeterministicItineraryGenerator();

  @override
  Future<List<DailyPlanModel>> generate(TripDraft draft) async {
    final location = draft.destination.trim().isEmpty ? 'Your trip' : draft.destination.trim();
    final days = draft.durationDays;

    return List<DailyPlanModel>.generate(days, (index) {
      return DailyPlanModel(
        title: 'Day ${index + 1}',
        location: location,
        plan: const PlanModel(favorited: <String>[], locations: <LocationPlanModel>[]),
      );
    });
  }
}
