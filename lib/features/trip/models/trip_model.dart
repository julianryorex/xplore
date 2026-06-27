import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/timestamp_converter.dart';
import 'package:xplore/features/trip/models/trip_preferences.dart';

part '../../../generated/features/trip/models/trip_model.freezed.dart';
part '../../../generated/features/trip/models/trip_model.g.dart';

@freezed
abstract class TripModel with _$TripModel {
  const factory TripModel({
    @JsonKey(includeToJson: false) required String id,
    required String title,
    required List<String> memberIds,
    required String createdBy,
    String? lastUpdatedBy,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastUpdatedAt,
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? endDate,
    String? coverImageUrl,

    /// Primary destination (single city for phase 1). Anchors cover art, the
    /// default map center, and itinerary generation.
    String? destination,

    /// Generation context captured during the create flow (interests, pace,
    /// budget, group). Persisted for later regeneration.
    TripPreferences? preferences,
  }) = _TripModel;

  factory TripModel.fromJson(Map<String, Object?> json) => _$TripModelFromJson(json);
}
