import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/map/bloc/map_cubit.freezed.dart';
part 'map_states.dart';

// TODO: Transit
// TODO: Add neighborhood polylines (watch dog like)
// TODO: Profile pictures as users
// TODO: InfoWindow with last updated

class MapCubit extends Cubit<MapStates> {
  late final Logger _logger;
  late String mapStyle;

  MapCubit() : super(InitialMapState()) {
    _logger = createLogger('Map');
    init();
  }

  static const initialCameraPosition = CameraPosition(target: LatLng(40.7128, -73.9571), zoom: 12.0);

  @visibleForTesting
  Future<void> init() async {
    await _loadMapStyle();
    final center = await getCurrentLocation();

    emit(LoadedMapState(center: center));
  }

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  void updateCenter(LatLng newCenter) {
    if (state is! InitialMapState) return;

    final currentState = state as LoadedMapState;
    emit(currentState.copyWith(center: newCenter));
  }

  Future<LatLng> getCurrentLocation() async {
    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> updateUserMarkers(List<LocationModel> locations) async {
    if (state is! LoadedMapState) return;

    _logger.d('Update location markers');
    // need to get user information for each location and save it to map

    final markers = locations.map(
      (el) {
        return Marker(
          markerId: MarkerId(el.id),
          position: LatLng(el.lat, el.lng),
          alpha: DateTime.now().difference(el.lastUpdated) > const Duration(minutes: 10) ? 0.5 : 1,
          // infoWindow: ,
          // icon: ,
        );
      },
    );

    emit((state as LoadedMapState).copyWith(markers: markers.toSet()));
  }

  //! -------------------------------------------------------------------------
  //! Helpers
  //! -------------------------------------------------------------------------

  /// Loads [GoogleMap] style
  Future<void> _loadMapStyle() async {
    mapStyle = await rootBundle.loadString('assets/maps/GoogleMapNeon.json');
  }
}
