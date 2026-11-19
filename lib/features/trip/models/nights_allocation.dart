import 'package:xplore/features/trip/models/trip_stop.dart';

/// Upper bound on a trip's length in nights, so a mistyped date range cannot
/// produce a plan with hundreds of days.
const maxTripNights = 60;

/// Nights a stop gets when it is added to a trip with flexible dates (there is
/// no fixed total to split, so the trip grows by this much).
const defaultFlexibleNights = 2;

/// Splits [total] nights across [count] stops: every stop gets at least one and
/// the remainder goes to the earliest stops. A single stop takes all nights,
/// even zero (a day trip). When [total] < [count] each stop gets one night as a
/// best effort; [evaluateNights] then reports [NightsIssue.fewerNightsThanStops].
List<int> splitNightsEvenly(int total, int count) {
  if (count <= 0) {
    return const [];
  }
  if (count == 1) {
    return [total < 0 ? 0 : total];
  }
  if (total < count) {
    return List.filled(count, 1);
  }
  final base = total ~/ count;
  final remainder = total % count;
  return List.generate(count, (index) => base + (index < remainder ? 1 : 0));
}

/// Whole nights between two calendar dates, ignoring time of day and DST.
int nightsBetween(DateTime start, DateTime end) =>
    DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

/// Strips the time of day so dates compare and add by calendar day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Why a trip's nights allocation is not usable. Checked in this order, so the
/// first issue is the most fundamental one for the UI to explain.
enum NightsIssue {
  /// The trip has no places yet.
  noStops,

  /// Exact dates were chosen but the range is incomplete.
  missingDates,

  /// The trip is longer than [maxTripNights].
  tooLong,

  /// Exact dates give fewer nights than there are places ("4 places need at
  /// least 4 nights"); no allocation can fix it short of changing dates/places.
  fewerNightsThanStops,

  /// A place has no nights (only a single-place day trip may have zero).
  stopWithoutNights,

  /// Exact dates: fewer nights assigned than the dates give ("9 of 10 nights assigned").
  unassigned,

  /// Exact dates: more nights assigned than the dates give ("11 of 10 nights assigned").
  overassigned,
}

/// A snapshot of how a trip's nights are spread over its stops, for the
/// "9 of 10 nights assigned" summary and its validation.
class NightsAllocation {
  const NightsAllocation({required this.assigned, required this.target, required this.stopCount, this.issue});

  /// Sum of every stop's nights.
  final int assigned;

  /// Nights the exact dates fix; null for flexible dates, where [assigned] is the trip length.
  final int? target;

  final int stopCount;

  /// The first problem found, or null when the allocation is valid.
  final NightsIssue? issue;

  /// Whether the allocation can be planned and saved as is.
  bool get isValid => issue == null;

  @override
  bool operator ==(Object other) =>
      other is NightsAllocation &&
      other.assigned == assigned &&
      other.target == target &&
      other.stopCount == stopCount &&
      other.issue == issue;

  @override
  int get hashCode => Object.hash(assigned, target, stopCount, issue);

  @override
  String toString() => 'NightsAllocation($assigned of $target over $stopCount stops, issue: $issue)';
}

/// Validates [stops]' nights. Pass [targetNights] for exact dates (the date
/// range fixes the total) and null for flexible dates (the sum is the length).
/// Set [missingDates] when exact dates were chosen without a complete range.
NightsAllocation evaluateNights(List<TripStop> stops, {int? targetNights, bool missingDates = false}) {
  final assigned = stops.fold<int>(0, (sum, stop) => sum + stop.nights);
  NightsAllocation result(NightsIssue? issue) =>
      NightsAllocation(assigned: assigned, target: targetNights, stopCount: stops.length, issue: issue);

  if (stops.isEmpty) {
    return result(NightsIssue.noStops);
  }
  if (missingDates) {
    return result(NightsIssue.missingDates);
  }
  if ((targetNights ?? assigned) > maxTripNights) {
    return result(NightsIssue.tooLong);
  }
  if (targetNights != null) {
    if (stops.length == 1 && targetNights == 0) {
      // A same-day trip to one place: the only valid allocation is zero nights.
      return result(stops.single.nights == 0 ? null : NightsIssue.overassigned);
    }
    if (targetNights < stops.length) {
      return result(NightsIssue.fewerNightsThanStops);
    }
  }
  if (stops.any((stop) => stop.nights < 1)) {
    return result(NightsIssue.stopWithoutNights);
  }
  if (targetNights != null && assigned != targetNights) {
    return result(assigned < targetNights ? NightsIssue.unassigned : NightsIssue.overassigned);
  }
  return result(null);
}

/// The calendar dates of one stay: arrive on [start], leave on [end].
class StayRange {
  const StayRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  /// Nights spent between arriving and leaving.
  int get nights => nightsBetween(start, end);

  @override
  bool operator ==(Object other) => other is StayRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'StayRange($start – $end)';
}

/// Stay dates for each of [stops] when the trip starts on [tripStart]: each
/// stay begins the day the previous one ends. Reflects the current nights even
/// when they do not add up to the trip's dates.
List<StayRange> stayRangesFrom(DateTime tripStart, List<TripStop> stops) {
  // Adding days through the constructor (not Duration) keeps midnights across DST changes.
  DateTime dayOfTrip(int offset) => DateTime(tripStart.year, tripStart.month, tripStart.day + offset);

  final ranges = <StayRange>[];
  var arrivalOffset = 0;
  for (final stop in stops) {
    final departureOffset = arrivalOffset + stop.nights;
    ranges.add(StayRange(start: dayOfTrip(arrivalOffset), end: dayOfTrip(departureOffset)));
    arrivalOffset = departureOffset;
  }
  return ranges;
}
