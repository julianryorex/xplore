import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/timestamp_converter.dart';
import 'package:xplore/features/trip/models/trip_preferences.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';

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

    /// Legacy single-string destination: the stop names joined (or one city for
    /// trips created before stops existed). Anchors cover art, the default map
    /// center, and itinerary generation.
    String? destination,

    /// The places in visiting order with their nights. Empty for trips created
    /// before multi-place trips; read [headline] for display.
    @Default(<TripStop>[]) List<TripStop> stops,

    /// Generation context captured during the create flow (interests, pace,
    /// budget, group). Persisted for later regeneration.
    TripPreferences? preferences,
  }) = _TripModel;

  const TripModel._();

  /// The place name to headline the trip with: [stopsHeadline] when it has
  /// stops (e.g. "Japan" rather than every city), otherwise the legacy
  /// [destination]. Null when neither is set.
  String? get headline {
    final label = stops.isNotEmpty ? stopsHeadline(stops) : destination?.trim() ?? '';
    return label.isEmpty ? null : label;
  }

  factory TripModel.fromJson(Map<String, Object?> json) => _$TripModelFromJson(json);
}
