import 'dart:math' as math;

import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

const _monthAbbreviations = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Abbreviated month name for [date], e.g. "Apr".
String monthAbbreviation(DateTime date) => _monthAbbreviations[date.month - 1];

/// Short calendar label for [date], e.g. "Apr 5".
String formatMonthDay(DateTime date) => '${monthAbbreviation(date)} ${date.day}';

/// Where today falls relative to the trip's dates.
enum TripTiming { undated, upcoming, ongoing, past }

/// Read-only figures the home and agent screens derive from the active trip
/// and its itinerary: countdown, trip length, and how much of it is planned.
class TripOverview {
  TripOverview({required this.trip, this.dailyPlans = const [], DateTime? now})
    : _today = _dateOnly(now ?? DateTime.now());

  final TripModel trip;
  final List<DailyPlanModel> dailyPlans;
  final DateTime _today;

  DateTime? get _start => trip.startDate == null ? null : _dateOnly(trip.startDate!);
  DateTime? get _end => trip.endDate == null ? null : _dateOnly(trip.endDate!);

  /// Days the trip spans: from its dates when set, otherwise from the number of
  /// itinerary days. Null when neither is known.
  int? get lengthInDays {
    final start = _start;
    final end = _end;
    if (start != null && end != null && !end.isBefore(start)) {
      return _daysBetween(start, end) + 1;
    }
    return dailyPlans.isEmpty ? null : dailyPlans.length;
  }

  TripTiming get timing {
    final start = _start;
    if (start == null) {
      return TripTiming.undated;
    }
    if (_today.isBefore(start)) {
      return TripTiming.upcoming;
    }
    final end = _end ?? start;
    return _today.isAfter(end) ? TripTiming.past : TripTiming.ongoing;
  }

  /// Whole days until the trip starts; null unless the trip is [TripTiming.upcoming].
  int? get daysToGo => timing == TripTiming.upcoming ? _daysBetween(_today, _start!) : null;

  /// 1-based day of the trip today is; null unless the trip is [TripTiming.ongoing].
  int? get currentDayNumber => timing == TripTiming.ongoing ? _daysBetween(_start!, _today) + 1 : null;

  /// Itinerary days that have at least one stop.
  int get plannedDays => dailyPlans.where(_hasStops).length;

  /// Days of the trip that still have no stops.
  int get openDays => math.max(0, (lengthInDays ?? 0) - plannedDays);

  /// Index of the first itinerary day with no stops, or null when every day has one.
  int? get firstEmptyDayIndex {
    final index = dailyPlans.indexWhere((day) => !_hasStops(day));
    return index == -1 ? null : index;
  }

  /// Calendar date of the itinerary day at [dayIndex], or null for an undated trip.
  DateTime? dateOfDay(int dayIndex) => _start?.add(Duration(days: dayIndex));

  /// How to refer to the itinerary day at [dayIndex] in a sentence: its date
  /// ("Apr 5") when the trip has dates, otherwise its position ("Day 3").
  String dayLabel(int dayIndex) {
    final date = dateOfDay(dayIndex);
    return date == null ? 'Day ${dayIndex + 1}' : formatMonthDay(date);
  }

  /// "Apr 3 – Apr 9", or null when the trip has no complete date range.
  String? get dateRangeLabel {
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      return null;
    }
    return '${formatMonthDay(start)} – ${formatMonthDay(end)}';
  }

  bool get isSolo => trip.memberIds.length <= 1;

  static bool _hasStops(DailyPlanModel day) => day.plan.locations.isNotEmpty;

  static DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  // Dates are normalised to UTC midnights, so the difference is DST-safe.
  static int _daysBetween(DateTime from, DateTime to) => to.difference(from).inDays;
}
