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
  ///
  /// While [isSaving] or after a [saveFailure], [itinerary] already shows the
  /// edit even though the group cannot see it yet, so the plan never disappears.
  const factory LoadedItineraryState({
    required ItineraryModel itinerary,
    @Default(false) bool canEdit,
    @Default(false) bool isSaving,
    ItinerarySaveFailure? saveFailure,
  }) = _LoadedItineraryState;
}

/// The kinds of edit [ItineraryCubit] saves.
enum ItineraryEdit { addStop, updateStop, completeStop, removeStop, reorderStops, addDay, renameDay, removeDay }

/// The latest edit that could not be saved. [dayIndex] and [stopIndex] point
/// at the stop to mark "Not saved" when the edit added or changed one.
@freezed
abstract class ItinerarySaveFailure with _$ItinerarySaveFailure {
  const ItinerarySaveFailure._();

  const factory ItinerarySaveFailure({required ItineraryEdit edit, int? dayIndex, int? stopIndex}) =
      _ItinerarySaveFailure;

  /// Whether the stop at [stop] on day [day] is the one that was not saved.
  bool marksStop(int day, int stop) => dayIndex == day && stopIndex == stop;
}
