part of 'itinerary_cubit.dart';

sealed class ItineraryStates {
  const ItineraryStates();
}

/// Pre-subscription default (no active trip resolved yet).
class InitialItineraryState extends ItineraryStates {
  const InitialItineraryState();
}

/// A trip is active and its itinerary is being fetched from the cloud.
class LoadingItineraryState extends ItineraryStates {
  const LoadingItineraryState();
}

/// No active trip (signed out / no trips), or seeding failed.
class EmptyItineraryState extends ItineraryStates {
  const EmptyItineraryState();
}

/// The itinerary stream errored.
class ErrorItineraryState extends ItineraryStates {
  const ErrorItineraryState(this.message);

  final String message;
}

@freezed
abstract class LoadedItineraryState extends ItineraryStates with _$LoadedItineraryState {
  const LoadedItineraryState._();

  /// [canEdit] is true only for the trip owner (`trips/{tripId}.createdBy`).
  /// Editing is owner-only this pass (co-editor roles → FEAT-024); the UI hides
  /// all edit affordances when false and the cubit's mutators no-op.
  const factory LoadedItineraryState({required ItineraryModel itinerary, @Default(false) bool canEdit}) =
      _LoadedItineraryState;
}
