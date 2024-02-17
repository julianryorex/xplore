import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

part '../../../generated/features/map/bloc/map_cubit.freezed.dart';
part 'map_states.dart';

class MapCubit extends Cubit<MapStates> {
  static const initialCameraPosition = CameraPosition(target: LatLng(40.7128, -73.9571), zoom: 12.0);
  late String mapStyle;

  MapCubit() : super(InitialMapState()) {
    init();
  }

  Future<void> init() async {
    await _loadMapStyle();
    final center = await getCurrentLocation();

    emit(LoadedMapState(center: center));
  }

  void updateCenter(LatLng newCenter) {
    if (state is! InitialMapState) {
      return;
    }

    final currentState = state as LoadedMapState;
    emit(currentState.copyWith(center: newCenter));
  }

  Future<LatLng> getCurrentLocation() async {
    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  /// Loads [GoogleMap] style
  Future<void> _loadMapStyle() async {
    mapStyle = await rootBundle.loadString('assets/maps/GoogleMapNeon.json');
  }
}
