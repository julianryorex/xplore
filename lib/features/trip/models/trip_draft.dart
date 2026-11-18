import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_preferences.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';

part '../../../generated/features/trip/models/trip_draft.freezed.dart';

/// Who the trip is for. Captured as a *generation signal*, never as a gate —
/// [TripGroupKind.solo] is a fully-supported first-class default.
enum TripGroupKind {
  solo('Solo', 'Just me'),
  couple('Couple', 'Two of us'),
  friends('Friends', 'A group of friends'),
  family('Family', 'Family trip');

  const TripGroupKind(this.label, this.description);

  final String label;
  final String description;
}

enum TripPace {
  chill('Chill', 'Lots of downtime'),
  balanced('Balanced', 'A bit of everything'),
  packed('Packed', 'See as much as possible');

  const TripPace(this.label, this.description);

  final String label;
  final String description;
}

enum TripBudget {
  budget(r'$', 'Budget-friendly'),
  moderate(r'$$', 'Comfortable'),
  luxury(r'$$$', 'Treat ourselves');

  const TripBudget(this.label, this.description);

  final String label;
  final String description;
}

enum TripInterest {
  food('Food & drink'),
  culture('Culture'),
  nightlife('Nightlife'),
  nature('Nature'),
  shopping('Shopping'),
  relaxation('Relaxation');

  const TripInterest(this.label);

  final String label;
}

/// Longest trip name the trip document accepts (see `infra/rules/firestore.rules`).
const maxTripTitleLength = 80;

/// A flat, additive draft accumulated as the user moves through the
/// create-trip flow. Deliberately flat so adding a new field never breaks an
/// existing step (FEAT-007 extensibility principle).
@freezed
abstract class TripDraft with _$TripDraft {
  const factory TripDraft({
    /// The places in visiting order, each with its nights.
    @Default(<TripStop>[]) List<TripStop> stops,
    @Default(true) bool datesAreFlexible,

    /// Date-only (no time of day) when set through the cubit. Only meaningful
    /// while [datesAreFlexible] is false; kept otherwise so the picker can
    /// pre-fill if the user switches back.
    DateTime? startDate,
    DateTime? endDate,
    @Default(TripGroupKind.solo) TripGroupKind groupKind,
    @Default(1) int groupSize,
    @Default(<TripInterest>{}) Set<TripInterest> interests,
    @Default(TripPace.balanced) TripPace pace,
    @Default(TripBudget.moderate) TripBudget budget,
    @Default('') String notes,

    /// What the user typed as the trip name; empty means "use [suggestedTitle]".
    @Default('') String title,
    String? coverImageUrl,
  }) = _TripDraft;

  const TripDraft._();

  /// Legacy single-string destination: the stop names in visiting order,
  /// comma separated (e.g. "Tokyo, Kyoto"). Empty without stops.
  String get destination => stops.map((stop) => stop.name).join(', ');

  /// The place label the home hero shows for this trip; see [stopsHeadline].
  String get headline => stopsHeadline(stops);

  bool get isSolo => groupKind == TripGroupKind.solo;

  /// Whether the trip runs on exact dates with a complete range.
  bool get hasExactDates => !datesAreFlexible && startDate != null && endDate != null;

  /// Nights fixed by the exact date range; null for flexible or incomplete dates.
  int? get targetNights => hasExactDates ? nightsBetween(startDate!, endDate!) : null;

  /// Sum of every stop's nights.
  int get assignedNights => stops.fold(0, (sum, stop) => sum + stop.nights);

  /// The trip's length in nights: fixed by the dates when exact, otherwise the
  /// sum of the stops' nights.
  int get totalNights => targetNights ?? assignedNights;

  /// Number of days the trip spans: [totalNights] + 1 (the departure day), so a
  /// same-day trip is 1 day. Always >= 1.
  int get durationDays => totalNights < 0 ? 1 : totalNights + 1;

  /// How the nights are spread over the stops and whether that is valid; drives
  /// the "9 of 10 nights assigned" summary.
  NightsAllocation get nightsAllocation =>
      evaluateNights(stops, targetNights: targetNights, missingDates: !datesAreFlexible && !hasExactDates);

  /// Whether the nights can be planned and saved as they are.
  bool get isNightsAllocationValid => nightsAllocation.isValid;

  /// Arrival and departure dates of the stop at [stopIndex] on an exact-date
  /// trip, following the current nights; null for flexible dates or a bad index.
  StayRange? stayRangeFor(int stopIndex) {
    if (!hasExactDates || stopIndex < 0 || stopIndex >= stops.length) {
      return null;
    }
    return stayRangesFrom(startDate!, stops)[stopIndex];
  }

  /// A friendly auto-suggested name, e.g. "Japan with friends", "Tokyo for
  /// two", "Solo in Lisbon" or "Family trip to Bali". Used until the user types
  /// a [title].
  String get suggestedTitle {
    final place = _titlePlace;
    if (place.isEmpty) {
      return 'My trip';
    }
    return switch (groupKind) {
      TripGroupKind.solo => 'Solo in $place',
      TripGroupKind.couple => '$place for two',
      TripGroupKind.friends => '$place with friends',
      TripGroupKind.family => 'Family trip to $place',
    };
  }

  /// The name the trip is created with: the typed [title], or [suggestedTitle]
  /// while it is blank.
  String get effectiveTitle => title.trim().isEmpty ? suggestedTitle : title.trim();

  String get _titlePlace {
    if (stops.isEmpty) {
      return '';
    }
    if (stops.length == 1) {
      return stops.single.name;
    }
    final countries = stopCountries(stops);
    return switch (countries.length) {
      0 => stops.first.name,
      1 => countries.single,
      2 => '${countries[0]} and ${countries[1]}',
      _ => '${countries.first} and beyond',
    };
  }

  /// The persisted projection written onto the trip document.
  TripPreferences toPreferences() {
    return TripPreferences(
      interests: interests.map((i) => i.name).toList(),
      pace: pace.name,
      budget: budget.name,
      groupKind: groupKind.name,
      groupSize: groupSize,
      notes: notes.trim().isEmpty ? null : notes.trim(),
    );
  }
}
