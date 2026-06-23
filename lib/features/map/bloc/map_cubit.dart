import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/features/location/utils/last_seen.dart';
import 'package:xplore/features/map/services/marker_service.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/map/bloc/map_cubit.freezed.dart';
part 'map_states.dart';

// TODO: Transit
// TODO: Add neighborhood polylines (watch dog like)

class MapCubit extends Cubit<MapStates> {
  late final Logger _logger;
  late String mapStyle;
  late MarkerService markerService;

  MapCubit() : super(InitialMapState()) {
    _logger = createLogger('Map');
    markerService = MarkerService();
    init();
  }

  static const initialCameraPosition = CameraPosition(target: LatLng(40.7128, -73.9571), zoom: 12.0);

  @visibleForTesting
  Future<void> init() async {
    await _loadMapStyle();
    await checkUserMarkerState();
  }

  Future<void> checkUserMarkerState() async {
    final userMarker = await markerService.fetchMarkerIcon(userId);

    if (userMarker == null) {
      emit(LoadProfileOnMapState());
      return;
    }

    emit(const LoadedMapState());
  }

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  Future<void> initialMarkerUpdate() async {
    final iconBytes = await markerService.convertMarkerWidgetToBytes();
    _logger.d('Generated iconBytes (${iconBytes?.length} bytes)');
    await markerService.updateMarkerIcon(userId, iconBytes!);
    emit(const LoadedMapState());
  }

  void updateCenter(LatLng newCenter) {
    final currentState = state as LoadedMapState;
    emit(currentState.copyWith(center: newCenter));
  }

  Future<void> updateUserMarkers(List<LocationModel> locations) async {
    if (state is! LoadedMapState) return;

    List<Marker> markersV2 = [];

    for (var el in locations) {
      final userMarker = await markerService.fetchMarkerIcon(el.id);
      final markerIcon = userMarker != null ? BitmapDescriptor.bytes(userMarker) : BitmapDescriptor.defaultMarker;

      final stale = isLocationStale(el.lastUpdated);

      final marker = Marker(
        markerId: MarkerId(el.id),
        position: LatLng(el.lat, el.lng),
        anchor: userMarker != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
        alpha: stale ? 0.5 : 1,
        icon: markerIcon,
        infoWindow: InfoWindow(title: 'Last seen ${formatLastSeen(el.lastUpdated)}', anchor: const Offset(-0.5, 0.0)),
      );

      markersV2.add(marker);
    }

    emit((state as LoadedMapState).copyWith(markers: markersV2.toSet()));
    _logger.d('Location markers updated');
  }

  //! -------------------------------------------------------------------------
  //! Helpers
  //! -------------------------------------------------------------------------

  @visibleForTesting
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
