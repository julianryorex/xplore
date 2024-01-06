part of 'location_cubit.dart';

@freezed
class LocationState with _$LocationState {
  const factory LocationState({
    required Map<String, LocationModel> locations,
  }) = _LocationState;
}
