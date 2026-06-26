import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/trip_preferences.dart';

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

/// A flat, additive draft accumulated as the user moves through the
/// create-trip flow. Deliberately flat so adding a new field never breaks an
/// existing step (FEAT-007 extensibility principle).
@freezed
abstract class TripDraft with _$TripDraft {
  const factory TripDraft({
    @Default('') String destination,
    @Default(true) bool datesAreFlexible,
    DateTime? startDate,
    DateTime? endDate,
    @Default(3) int flexibleDurationDays,
    @Default(TripGroupKind.solo) TripGroupKind groupKind,
    @Default(1) int groupSize,
    @Default(<TripInterest>{}) Set<TripInterest> interests,
    @Default(TripPace.balanced) TripPace pace,
    @Default(TripBudget.moderate) TripBudget budget,
    @Default('') String notes,
    @Default('') String title,
    String? coverImageUrl,
  }) = _TripDraft;

  const TripDraft._();

  /// Number of days the generated itinerary should span. Exact dates win when
  /// present; otherwise the user's flexible duration drives it. Always >= 1.
  int get durationDays {
    final start = startDate;
    final end = endDate;
    if (!datesAreFlexible && start != null && end != null) {
      final span = end.difference(start).inDays + 1;
      return span.clamp(1, 30);
    }
    return flexibleDurationDays.clamp(1, 30);
  }

  bool get isSolo => groupKind == TripGroupKind.solo;

  /// A friendly auto-suggested name derived from the destination, used to
  /// pre-fill the finishing-touches step.
  String get suggestedTitle {
    final place = destination.trim();
    if (place.isEmpty) {
      return 'My trip';
    }
    return switch (groupKind) {
      TripGroupKind.solo => '$place getaway',
      TripGroupKind.couple => '$place for two',
      TripGroupKind.friends => '$place with friends',
      TripGroupKind.family => '$place family trip',
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
