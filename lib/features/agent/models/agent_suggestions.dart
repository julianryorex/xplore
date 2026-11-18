import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

/// "Try asking" prompts for the agent screen, derived only from what the
/// loaded itinerary actually contains. Empty when there is nothing worth
/// suggesting (no itinerary days, or the trip is over).
List<String> agentSuggestions(TripOverview overview) {
  final days = overview.dailyPlans;
  if (days.isEmpty || overview.timing == TripTiming.past) {
    return const [];
  }

  final thinDayIndex = days.indexWhere((day) => _stopCount(day) >= 1 && _stopCount(day) <= 2);

  return [
    ?overview.suggestedPlanDayPrompt,
    if (thinDayIndex != -1) 'Fill out ${overview.dayTitle(thinDayIndex)}',
    if (overview.openDays > 1) 'Draft all ${overview.openDays} open days',
    if (days.length >= 2 && days.any((day) => _stopCount(day) > 0)) 'Move a stop to another day',
  ];
}

int _stopCount(DailyPlanModel day) => day.plan.locations.length;
