import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/datetime_json_converter.dart';

part '../../../generated/features/location/models/location_models.freezed.dart';
part '../../../generated/features/location/models/location_models.g.dart';

@freezed
abstract class LocationModel with _$LocationModel {
  const factory LocationModel({
    required String id,
    required double lat,
    required double lng,
    @JsonKey(name: 'last_updated') @DateTimeConverter() required DateTime lastUpdated,
  }) = _LocationModel;

  factory LocationModel.fromJson(Map<String, Object?> json) => _$LocationModelFromJson(json);
}
