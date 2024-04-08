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
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/location/bloc/location_cubit.freezed.dart';
part 'location_states.dart';

// TODO: test if this still works with app in the foreground
// TODO: look into background fetch
// TODO: use real user id from auth

class LocationCubit extends Cubit<LocationState> {
  late final Logger _logger;

  /// Timer where every min user location is updated & fetched to/from the cloud
  late Timer updateLocationTimer;

  StreamSubscription<DatabaseEvent>? locationSubscription;

  static const locationUpdateInterval = 10;

  LocationCubit() : super(const LocationState(locations: {})) {
    _logger = createLogger('Location');
    loadDemoLocations();

    if (dotenv.env['DISABLE_REALTIME_LOCATIONS'].toBool()) {
      _logger.i('Disabled realtime location update');
      return;
    }

    _logger.i('Enabled realtime location update');
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

  void endTimer() => updateLocationTimer.cancel();

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

  @visibleForTesting
  Future<void> timerCallback(Timer timer) async {
    // every 5 minutes, I will update my location and fetch all locations within the itinerary

    DatabaseReference locationRef = FirebaseDatabase.instance.ref('locations/$itineraryId');

    // set my location
    final myCoords = await getCurrentLocation();
    final myLocation = LocationModel(
      id: userId,
      lastUpdated: DateTime.now(),
      lat: myCoords.latitude,
      lng: myCoords.longitude,
    );
    await locationRef.child(userId).set(myLocation.toJson());

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

    final locationsFromJson = demoData['locations']['ph4kd'] as Map<String, dynamic>;

    final Map<String, LocationModel> locationMap = {};

    locationsFromJson.entries.forEach((loc) {
      locationMap[loc.key] = LocationModel.fromJson(loc.value);
    });

    emit(LocationState(locations: locationMap));
  }

  @override
  Future<void> close() {
    _logger.d('Disposing');
    updateLocationTimer.cancel();
    locationSubscription?.cancel();
    return super.close();
  }
}
