import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/location/bloc/location_cubit.freezed.dart';
part 'location_states.dart';

// TODO: test if this still works with app in the foreground
// TODO: look into background fetch

class LocationCubit extends Cubit<LocationState> with TripStreamMixin {
  late final Logger _logger;
  final AuthService _authService;
  StreamSubscription<TripState>? _tripSubscription;
  String? _activeTripId;

  /// Timer that periodically updates and fetches user locations from the cloud.
  Timer? updateLocationTimer;

  StreamSubscription<DatabaseEvent>? locationSubscription;

  static const locationUpdateInterval = 10;

  LocationCubit(this._authService) : super(const LocationState(locations: {})) {
    _logger = createLogger('Location');
    _tripSubscription = listenToTripState(_onTripStateChanged);
    updateMyLocation();

    if (dotenv.env['DISABLE_REALTIME_LOCATIONS'].toBool()) {
      _logger.i('Disabled real-time location updates');
      return;
    }

    _logger.i('Enabled real-time location updates');
    startTimer();
  }

  void startTimer() {
    int updateInterval = locationUpdateInterval;
    if (dotenv.env.containsKey('LOCATION_INTERVAL_UPDATE')) {
      updateInterval = int.parse(dotenv.env['LOCATION_INTERVAL_UPDATE']!);
      _logger.d('Custom time interval started for location updates');
    }

    updateLocationTimer = Timer.periodic(Duration(seconds: updateInterval), timerCallback);
  }

  void endTimer() => updateLocationTimer?.cancel();

  /// The active Firebase UID, or null when unauthenticated.
  String? get _uid => _authService.currentUid;

  String get _tripScopeId => _activeTripId ?? itineraryId;

  //! -------------------------------------------------------------------------
  //! Public Methods
  //! -------------------------------------------------------------------------

  Future<LatLng> getCurrentLocation() async {
    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  //! -------------------------------------------------------------------------
  //! Private Methods
  //! -------------------------------------------------------------------------

  Future<void> updateMyLocation() async {
    // Pre-auth (the cubit is created eagerly at app start) there is no UID to
    // write a location for, so skip until the user is signed in.
    final uid = _uid;
    if (uid == null) {
      _logger.d('Skipping location update: not authenticated');
      return;
    }

    DatabaseReference locationRef = FirebaseDatabase.instance.ref('locations/$_tripScopeId');

    final myCoords = await getCurrentLocation();
    final myLocation = LocationModel(
      id: uid,
      lastUpdated: DateTime.now(),
      lat: myCoords.latitude,
      lng: myCoords.longitude,
    );

    emit(state.copyWith(locations: {uid: myLocation}));
    await locationRef.child(uid).set(myLocation.toJson());
  }

  @visibleForTesting
  Future<void> timerCallback(Timer timer) async {
    // Refresh my location, then fetch all locations for the active trip.

    DatabaseReference locationRef = FirebaseDatabase.instance.ref('locations/$_tripScopeId');

    await updateMyLocation();

    // fetch all locations
    final snapshot = await locationRef.get();
    final allLocations = snapshot.children.map((loc) {
      final locValue = loc.value as Map<Object?, Object?>;
      return {
        loc.key!: LocationModel(
          id: loc.key!,
          lat: double.parse((locValue['lat'] ?? '0').toString()),
          lng: double.parse((locValue['lng'] ?? '0').toString()),
          lastUpdated: DateTime.tryParse(locValue['last_updated'] as String) ?? DateTime.now(),
        ),
      };
    });

    final Map<String, LocationModel> locationMap = {};
    for (var map in allLocations) {
      locationMap.addAll(map);
    }

    emit(state.copyWith(locations: locationMap));
    _logger.d('Location updated & fetched ${allLocations.length} locations');
  }

  @visibleForTesting
  Future<void> loadDemoLocations() async {
    final Map<String, dynamic> demoData = await loadJsonAsset('assets/demo/locations.json');

    final locationsFromJson = demoData['locations'][itineraryId] as Map<String, dynamic>;

    final Map<String, LocationModel> locationMap = {};

    for (final loc in locationsFromJson.entries) {
      locationMap[loc.key] = LocationModel.fromJson(loc.value);
    }

    _logger.d('Loaded ${locationMap.entries.length} demo locations.');

    emit(LocationState(locations: locationMap));
  }

  void _onTripStateChanged(TripState tripState) {
    switch (tripState) {
      case TripLoaded(:final active):
        _activeTripId = active.id;
      case TripEmpty() || TripError():
        _activeTripId = null;
      case TripLoading():
        break;
    }
  }

  @override
  Future<void> close() async {
    _logger.d('Disposing');
    updateLocationTimer?.cancel();
    await locationSubscription?.cancel();
    await _tripSubscription?.cancel();
    return super.close();
  }
}
