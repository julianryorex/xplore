import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/itinerary_date_converter.dart';

part '../../../generated/features/itinerary/models/itinerary_models.freezed.dart';
part '../../../generated/features/itinerary/models/itinerary_models.g.dart';

@freezed
abstract class ItineraryModel with _$ItineraryModel {
  const factory ItineraryModel({
    required String id,
    required List<String> invitees,
    @JsonKey(name: 'daily_plans') required List<DailyPlanModel> dailyPlans,
    required List<dynamic> pins,
    // Nullable so a freshly seeded doc whose `serverTimestamp()` is still
    // pending (null on the local snapshot) parses without throwing.
    @JsonKey(name: 'last_updated') @ItineraryDateConverter() DateTime? lastUpdated,
  }) = _ItineraryModel;

  factory ItineraryModel.fromJson(Map<String, Object?> json) => _$ItineraryModelFromJson(json);
}

@freezed
abstract class DailyPlanModel with _$DailyPlanModel {
  const factory DailyPlanModel({
    required String title,
    required String location,
    required PlanModel plan,
    // The latest change to the day itself: added, renamed, a stop removed or its stops reordered.
    @JsonKey(name: 'last_change') ItineraryChangeModel? lastChange,
  }) = _DailyPlanModel;

  factory DailyPlanModel.fromJson(Map<String, Object?> json) => _$DailyPlanModelFromJson(json);
}

@freezed
abstract class PlanModel with _$PlanModel {
  const factory PlanModel({required List<String> favorited, required List<LocationPlanModel> locations}) = _PlanModel;

  factory PlanModel.fromJson(Map<String, Object?> json) => _$PlanModelFromJson(json);
}

/// One stop on a day. A stop is a real place when [placeId] is set, and then
/// carries the place details saved when it was picked so viewing a plan never
/// searches again. With an empty [placeId] it is a custom stop: a free-text
/// [name] with no place details. Documents written before place details
/// existed lack those fields and read as empty strings.
@freezed
abstract class LocationPlanModel with _$LocationPlanModel {
  const LocationPlanModel._();

  const factory LocationPlanModel({
    required String name,
    @Default(false) bool completed,
    @JsonKey(name: 'place_id') @Default('') String placeId,
    // The note for the group.
    @Default('') String description,
    @Default('') String category,
    @Default('') String neighbourhood,
    @Default('') String address,
    // Daily hours as "HH:MM–HH:MM", or free text such as "Open 24 hours".
    @JsonKey(name: 'opening_hours') @Default('') String openingHours,
    @JsonKey(name: 'photo_reference') @Default('') String photoReference,
    // The latest change to this stop: added or edited.
    @JsonKey(name: 'last_change') ItineraryChangeModel? lastChange,
  }) = _LocationPlanModel;

  factory LocationPlanModel.fromJson(Map<String, Object?> json) => _$LocationPlanModelFromJson(json);

  /// True for a free-text stop that is not tied to a real place.
  bool get isCustom => placeId.isEmpty;
}

/// What kind of change an [ItineraryChangeModel] records.
enum ItineraryChangeAction {
  added,
  edited,
  renamed,
  @JsonValue('stop_removed')
  stopRemoved,
  @JsonValue('stops_reordered')
  stopsReordered,
}

/// Who made a change: a person on the trip, or Scout (the planning agent).
enum ChangeAuthorType { person, scout }

/// Who last changed a stop or a day, and when. Stored on the changed item
/// inside `daily_plans`; nothing in the app displays it yet.
@freezed
abstract class ItineraryChangeModel with _$ItineraryChangeModel {
  const factory ItineraryChangeModel({
    @JsonKey(unknownEnumValue: ItineraryChangeAction.edited) required ItineraryChangeAction action,
    @JsonKey(name: 'author_type', unknownEnumValue: ChangeAuthorType.person) required ChangeAuthorType authorType,
    // Client clock: Firestore server timestamps cannot be written inside an array.
    @ItineraryDateConverter() required DateTime? at, // The person's uid; empty for Scout.
    @JsonKey(name: 'author_id') @Default('') String authorId,
  }) = _ItineraryChangeModel;

  factory ItineraryChangeModel.fromJson(Map<String, Object?> json) => _$ItineraryChangeModelFromJson(json);
}
