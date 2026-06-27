import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/trip/models/trip_preferences.freezed.dart';
part '../../../generated/features/trip/models/trip_preferences.g.dart';

/// Generation signal captured by the create-trip flow and persisted on the
/// trip so a later regenerate (FEAT-007 phase 2 / FEAT-010) can reuse the same
/// context. Stored as plain strings/ints so it round-trips through Firestore
/// and the Hive cache without bespoke converters.
@freezed
abstract class TripPreferences with _$TripPreferences {
  const factory TripPreferences({
    @Default(<String>[]) List<String> interests,
    String? pace,
    String? budget,
    String? groupKind,
    int? groupSize,
    String? notes,
  }) = _TripPreferences;

  factory TripPreferences.fromJson(Map<String, Object?> json) => _$TripPreferencesFromJson(json);
}
