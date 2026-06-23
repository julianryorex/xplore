part of 'map_cubit.dart';

abstract class MapStates {
  const MapStates();
}

class InitialMapState extends MapStates {
  const InitialMapState();
}

class LoadProfileOnMapState extends MapStates {
  const LoadProfileOnMapState();
}

@freezed
abstract class LoadedMapState extends MapStates with _$LoadedMapState {
  const LoadedMapState._();

  const factory LoadedMapState({LatLng? center, @Default({}) Set<Marker> markers}) = _LoadedMapState;
}
