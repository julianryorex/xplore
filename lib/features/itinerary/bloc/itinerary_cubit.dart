import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/itinerary/bloc/itinerary_cubit.freezed.dart';
part 'itinerary_states.dart';

class ItineraryCubit extends Cubit<ItineraryStates> {
  ItineraryCubit() : super(InitialItineraryState());

  Future<void> loadDemoItinerary() async {
    final Map<String, dynamic> demoData = await loadJsonAsset('assets/demo/itinerary.json');

    final itineraryList = demoData['itineraries'] as List<dynamic>;
    // TODO(FEAT-002): the active trip id will come from TripCubit; the demo data
    // is keyed by the `itineraryId` placeholder for now.
    final itinerary =
        itineraryList.firstWhere((el) => el.keys.first == itineraryId) as Map<String, dynamic>; // TODO: remove list
    log('itinerary');
    log(itinerary.toString());

    final itineraryModel = ItineraryModel.fromJson(itinerary[itineraryId]);

    log('itineraryModel:');
    log(itineraryModel.toString());
    emit(LoadedItineraryState(itinerary: itineraryModel));
  }
}
