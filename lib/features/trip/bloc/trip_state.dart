import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

part '../../../generated/features/trip/bloc/trip_state.freezed.dart';

@freezed
sealed class TripState with _$TripState {
  const factory TripState.loading() = TripLoading;

  const factory TripState.empty() = TripEmpty;

  const factory TripState.loaded({required TripModel active, required List<TripModel> all}) = TripLoaded;

  const factory TripState.error(String message) = TripError;
}
