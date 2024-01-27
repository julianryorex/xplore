part of 'location_cubit.dart';

abstract class LocationStates {}

class InitialLocationState extends LocationStates {}

@freezed
class LoadedLocationState extends LocationStates with _$LoadedLocationState {
  const factory LoadedLocationState({
    required Map<String, LocationModel> locations,
  }) = _LoadedLocationState;
}
