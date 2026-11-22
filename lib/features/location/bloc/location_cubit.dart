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
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/models/trip_window.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/location/bloc/location_cubit.freezed.dart';
part 'location_states.dart';

// TODO: test if this still works with app in the foreground
// TODO: look into background fetch

/// What to do with a member's location for a trip at a given moment.
enum LocationSharing {
  /// Read the device position and publish it to the group.
  share,

  /// Remove the member's last published position.
  clear,

  /// Neither read nor publish anything.
  off,
}

/// Location is shared only while a trip is under way. Once it has ended the last
/// position is cleared; before it starts, or while it has no dates, nothing is shared.
LocationSharing locationSharingFor(TripWindow window) {
  return switch (window) {
    TripWindow.underWay => LocationSharing.share,
    TripWindow.ended => LocationSharing.clear,
    TripWindow.upcoming || TripWindow.undated => LocationSharing.off,
  };
}

/// Publishes the signed-in member's position for the active trip while it is
/// under way, and polls the rest of the group's positions.
class LocationCubit extends Cubit<LocationState> with TripStreamMixin {
  late final Logger _logger;
  final AuthService _authService;
  final DateTime Function() _clock;
  StreamSubscription<TripState>? _tripSubscription;
  TripModel? _activeTrip;

  /// Trips whose ended-trip position this member already removed, so the timer
  /// does not issue a delete every tick.
  final Set<String> _clearedTripIds = {};

  /// Timer that periodically updates and fetches user locations from the cloud.
  Timer? _updateLocationTimer;

  static const locationUpdateInterval = 10;

  LocationCubit(this._authService, {this._clock = DateTime.now}) : super(const LocationState(locations: {})) {
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

    _updateLocationTimer = Timer.periodic(Duration(seconds: updateInterval), timerCallback);
  }

  /// The active Firebase UID, or null when unauthenticated.
  String? get _uid => _authService.currentUid;

  /// The sharing decision for the active trip right now; off without one.
  LocationSharing get _sharingNow {
    final trip = _activeTrip;
    if (trip == null) {
      return LocationSharing.off;
    }
    return locationSharingFor(tripWindowOn(_clock(), start: trip.startDate, end: trip.endDate));
  }

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

    // Without an active trip there is no scope to write into. No-op rather than
    // falling back to a shared/demo node.
    final tripId = _activeTrip?.id;
    if (tripId == null) {
      _logger.d('Skipping location update: no active trip');
      return;
    }

    switch (_sharingNow) {
      case LocationSharing.off:
        _logger.d('Skipping location update: trip is not under way');
        return;
      case LocationSharing.clear:
        await _clearMyLocation(tripId, uid);
        return;
      case LocationSharing.share:
        // The trip may have been extended after it was cleared; clear again if it ends.
        _clearedTripIds.remove(tripId);
    }

    // This runs off a timer, so it must never raise the system prompt itself:
    // onboarding and the map ask for location in context.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      _logger.d('Skipping location update: location permission not granted');
      return;
    }

    DatabaseReference locationRef = FirebaseDatabase.instance.ref('locations/$tripId');

    final position = await Geolocator.getCurrentPosition();
    final myLocation = LocationModel(id: uid, lastUpdated: _clock(), lat: position.latitude, lng: position.longitude);

    emit(state.copyWith(locations: {uid: myLocation}));
    await locationRef.child(uid).set(myLocation.toJson());
  }

  @visibleForTesting
  Future<void> timerCallback(Timer timer) async {
    // Refresh my location, then fetch all locations for the active trip.

    // Without an active trip there is no scope to read from. No-op rather than
    // falling back to a shared/demo node.
    final tripId = _activeTrip?.id;
    if (tripId == null) {
      _logger.d('Skipping location fetch: no active trip');
      return;
    }

    await updateMyLocation();

    // Outside a running trip the group's positions are not shown, so stale pins
    // from before or after the trip never reach the map.
    if (_sharingNow != LocationSharing.share) {
      emit(state.copyWith(locations: const {}));
      return;
    }

    DatabaseReference locationRef = FirebaseDatabase.instance.ref('locations/$tripId');

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

  /// Removes this member's last position for an ended trip, once per trip.
  Future<void> _clearMyLocation(String tripId, String uid) async {
    if (_clearedTripIds.contains(tripId)) {
      return;
    }
    await FirebaseDatabase.instance.ref('locations/$tripId').child(uid).remove();
    _clearedTripIds.add(tripId);
    _logger.d('Cleared my location for ended trip $tripId');
  }

  void _onTripStateChanged(TripState tripState) {
    switch (tripState) {
      case TripLoaded(:final active):
        _activeTrip = active;
      case TripEmpty() || TripError():
        _activeTrip = null;
      case TripLoading():
        break;
    }
  }

  @override
  Future<void> close() async {
    _logger.d('Disposing');
    _updateLocationTimer?.cancel();
    await _tripSubscription?.cancel();
    return super.close();
  }
}
