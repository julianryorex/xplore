import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/location/bloc/location_cubit.freezed.dart';
part 'location_states.dart';

class LocationCubit extends Cubit<LocationStates> {
  LocationCubit() : super(InitialLocationState()) {
    loadDemoLocations();
  }

  Future<void> loadDemoLocations() async {
    final Map<String, dynamic> demoData = await loadJsonAsset('assets/demo/locations.json');

    final locationsFromJson = demoData['locations']['ph4kd'] as Map<String, dynamic>;

    final Map<String, LocationModel> locationMap = {};

    locationsFromJson.entries.forEach((loc) {
      locationMap[loc.key] = LocationModel.fromJson(loc.value);
    });

    print(locationMap);
    emit(LoadedLocationState(locations: locationMap));
  }
}
