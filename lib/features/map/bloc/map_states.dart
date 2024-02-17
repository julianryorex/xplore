part of 'map_cubit.dart';

abstract class MapStates {}

class InitialMapState extends MapStates {}

@freezed
class LoadedMapState extends MapStates with _$LoadedMapState {
  const factory LoadedMapState() = _LoadedMapState;
}
