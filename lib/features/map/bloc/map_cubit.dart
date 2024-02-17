import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/map/bloc/map_cubit.freezed.dart';
part 'map_states.dart';

class MapCubit extends Cubit<MapStates> {
  late String mapStyle;

  MapCubit() : super(InitialMapState()) {
    loadDemoLocations();
    init();
  }

  Future<void> init() async {
    await _loadMapStyle();

    emit(const LoadedMapState());
  }

  /// Loads [GoogleMap] style
  Future<void> _loadMapStyle() async {
    mapStyle = await rootBundle.loadString('assets/maps/GoogleMapNeon.json');
  }

  Future<void> loadDemoLocations() async {}
}
