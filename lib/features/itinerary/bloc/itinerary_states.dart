part of 'itinerary_cubit.dart';

abstract class ItineraryStates {
  const ItineraryStates();
}

class InitialItineraryState extends ItineraryStates {
  const InitialItineraryState();
}

@freezed
abstract class LoadedItineraryState extends ItineraryStates with _$LoadedItineraryState {
  const LoadedItineraryState._();

  const factory LoadedItineraryState({
    required ItineraryModel itinerary,
  }) = _LoadedItineraryState;
}
