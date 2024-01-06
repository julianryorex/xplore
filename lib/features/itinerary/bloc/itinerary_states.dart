part of 'itinerary_cubit.dart';

abstract class ItineraryStates {}

class InitialItineraryState extends ItineraryStates {}

@freezed
class LoadedItineraryState extends ItineraryStates with _$LoadedItineraryState {
  const factory LoadedItineraryState({
    required ItineraryModel itinerary,
  }) = _LoadedItineraryState;
}
