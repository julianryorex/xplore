import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';

part '../../../generated/features/trip/models/trip_plan.freezed.dart';

/// The day-by-day plan shown on the create flow's plan step and seeded into the
/// trip's itinerary once it is created.
@freezed
abstract class TripPlan with _$TripPlan {
  const factory TripPlan({
    /// One entry per trip day, in order; what the itinerary is seeded with.
    required List<DailyPlanModel> days,

    /// The same days grouped by stop, in visiting order.
    required List<StopPlan> stops,
  }) = _TripPlan;
}

/// One stop's slice of a [TripPlan].
@freezed
abstract class StopPlan with _$StopPlan {
  const factory StopPlan({
    required TripStop stop,

    /// Position of [stop] in the trip (0-based).
    required int stopIndex,

    /// Indexes into [TripPlan.days] spent at this stop, ascending. The last stop
    /// also holds the departure day, so it has one more day than nights.
    required List<int> dayIndexes,
    required int nights,

    /// Arrival and departure dates; null for trips with flexible dates.
    StayRange? stay,
  }) = _StopPlan;
}
