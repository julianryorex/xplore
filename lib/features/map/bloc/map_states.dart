part of 'map_cubit.dart';

abstract class MapStates {}

class InitialMapState extends MapStates {}

class LoadProfileOnMapState extends MapStates {}

@freezed
class LoadedMapState extends MapStates with _$LoadedMapState {
  const factory LoadedMapState({
    LatLng? center,
    @Default({}) Set<Marker> markers,
  }) = _LoadedMapState;
}
