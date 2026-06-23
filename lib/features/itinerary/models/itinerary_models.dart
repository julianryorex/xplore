import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/datetime_json_converter.dart';

part '../../../generated/features/itinerary/models/itinerary_models.freezed.dart';
part '../../../generated/features/itinerary/models/itinerary_models.g.dart';

@freezed
abstract class ItineraryModel with _$ItineraryModel {
  const factory ItineraryModel({
    required String id,
    @JsonKey(name: 'last_updated') @DateTimeConverter() required DateTime lastUpdated,
    required List<String> invitees,
    @JsonKey(name: 'daily_plans') required List<DailyPlanModel> dailyPlans,
    required List<dynamic> pins,
  }) = _ItineraryModel;

  factory ItineraryModel.fromJson(Map<String, Object?> json) => _$ItineraryModelFromJson(json);
}

@freezed
abstract class DailyPlanModel with _$DailyPlanModel {
  const factory DailyPlanModel({required String title, required String location, required PlanModel plan}) =
      _DailyPlanModel;

  factory DailyPlanModel.fromJson(Map<String, Object?> json) => _$DailyPlanModelFromJson(json);
}

@freezed
abstract class PlanModel with _$PlanModel {
  const factory PlanModel({required List<String> favorited, required List<LocationPlanModel> locations}) = _PlanModel;

  factory PlanModel.fromJson(Map<String, Object?> json) => _$PlanModelFromJson(json);
}

@freezed
abstract class LocationPlanModel with _$LocationPlanModel {
  const factory LocationPlanModel({
    required String name,
    required bool completed,
    @JsonKey(name: 'place_id') required String placeId,
    required String description,
  }) = _LocationPlanModel;

  factory LocationPlanModel.fromJson(Map<String, Object?> json) => _$LocationPlanModelFromJson(json);
}
