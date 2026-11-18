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

  // An end date before the start date is treated as missing, so it never yields
  // a reversed range or a trip that has "ended" on its first day.
  DateTime? get _end {
    final start = _start;
    final end = trip.endDate == null ? null : _dateOnly(trip.endDate!);
    return start != null && end != null && end.isBefore(start) ? null : end;
  }

  /// Days the trip spans according to its dates, or null without a complete range.
  int? get _datedLength {
    final start = _start;
    final end = _end;
    return start == null || end == null ? null : _daysBetween(start, end) + 1;
  }

  /// Days the trip spans: from its dates when set, otherwise from the number of
  /// itinerary days. Null when neither is known.
  int? get lengthInDays => _datedLength ?? (dailyPlans.isEmpty ? null : dailyPlans.length);

  /// Itinerary days that fall within the trip's dates; all of them when undated.
  List<DailyPlanModel> get _tripDays {
    final length = _datedLength;
    return length == null || dailyPlans.length <= length ? dailyPlans : dailyPlans.sublist(0, length);
  }

  /// Index of the first day still worth planning: today's while the trip is
  /// under way, so days that have already passed are not suggested.
  int get _firstRemainingDayIndex => timing == TripTiming.ongoing ? currentDayNumber! - 1 : 0;

  /// Where today falls relative to the trip's dates. A trip without a (valid)
  /// end date counts as a single day.
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

  /// Itinerary days within the trip that have at least one stop.
  int get plannedDays => _tripDays.where(_hasStops).length;

  /// Remaining days of the trip (from today while it is under way) that still have no stops.
  int get openDays {
    final from = _firstRemainingDayIndex;
    final plannedRemaining = _tripDays.skip(from).where(_hasStops).length;
    return math.max(0, (lengthInDays ?? 0) - from - plannedRemaining);
  }

  /// Index of the first remaining itinerary day with no stops, or null when
  /// every one has some. Days already past are skipped while the trip is under way.
  int? get firstEmptyDayIndex {
    final index = _tripDays.indexWhere((day) => !_hasStops(day), _firstRemainingDayIndex);
    return index == -1 ? null : index;
  }

  /// Agent prompt asking to plan the itinerary day at [dayIndex], e.g. "Plan Apr 5 for me".
  String planDayPrompt(int dayIndex) => 'Plan ${dayLabel(dayIndex)} for me';

  /// [planDayPrompt] for the first remaining empty day, or null when there is
  /// none or the trip is over.
  String? get suggestedPlanDayPrompt {
    final index = firstEmptyDayIndex;
    return index == null || timing == TripTiming.past ? null : planDayPrompt(index);
  }

  /// Calendar date of the itinerary day at [dayIndex], or null for an undated trip.
  DateTime? dateOfDay(int dayIndex) => _start?.add(Duration(days: dayIndex));

  /// How to refer to the itinerary day at [dayIndex] in a sentence: its date
  /// ("Apr 5") when the trip has dates, otherwise its position ("Day 3").
  String dayLabel(int dayIndex) {
    final date = dateOfDay(dayIndex);
    return date == null ? 'Day ${dayIndex + 1}' : formatMonthDay(date);
  }

  /// The itinerary day's own title, or its [dayLabel] when the title is blank.
  String dayTitle(int dayIndex) {
    final title = dailyPlans[dayIndex].title.trim();
    return title.isEmpty ? dayLabel(dayIndex) : title;
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

  static bool _hasStops(DailyPlanModel day) => day.plan.locations.isNotEmpty;

  static DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  // Dates are normalised to UTC midnights, so the difference is DST-safe.
  static int _daysBetween(DateTime from, DateTime to) => to.difference(from).inDays;
}
