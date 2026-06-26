import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/itinerary_generator.dart';
import 'package:xplore/utilities/utilities.dart';

/// Drives the multi-step create-trip flow (FEAT-007). Holds a single
/// [TripDraft], the ordered [CreateTripStep] list, and the generate/submit
/// lifecycle. Imports no other cubit; the actual trip persistence runs through
/// `TripCubit.createTripFromDraft` from the flow widget.
class TripCreationCubit extends Cubit<TripCreationState> {
  TripCreationCubit(this._generator, {List<CreateTripStep>? steps})
    : super(TripCreationState(draft: const TripDraft(), steps: steps ?? CreateTripStep.values));

  final ItineraryGenerator _generator;
  final Logger _logger = createLogger('TripCreation');

  void _update(TripDraft draft) => emit(state.copyWith(draft: draft));

  // --- Step navigation ------------------------------------------------------

  void next() {
    if (state.isLastStep) {
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex + 1));
  }

  void back() {
    if (state.isFirstStep) {
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex - 1));
  }

  // --- Draft mutations ------------------------------------------------------

  void setDestination(String value) {
    _update(state.draft.copyWith(destination: value));
    _invalidateGeneration();
  }

  void setExactDates(DateTime start, DateTime end) {
    _update(state.draft.copyWith(datesAreFlexible: false, startDate: start, endDate: end));
    _invalidateGeneration();
  }

  void setFlexibleDuration(int days) {
    _update(state.draft.copyWith(datesAreFlexible: true, flexibleDurationDays: days.clamp(1, 30)));
    _invalidateGeneration();
  }

  void setGroup(TripGroupKind kind, {int? size}) {
    final resolvedSize = size ?? _defaultSizeFor(kind);
    _update(state.draft.copyWith(groupKind: kind, groupSize: resolvedSize));
    _invalidateGeneration();
  }

  void setGroupSize(int size) {
    _update(state.draft.copyWith(groupSize: size.clamp(1, 50)));
    _invalidateGeneration();
  }

  void toggleInterest(TripInterest interest) {
    final next = Set<TripInterest>.from(state.draft.interests);
    if (!next.add(interest)) {
      next.remove(interest);
    }
    _update(state.draft.copyWith(interests: next));
    _invalidateGeneration();
  }

  void setPace(TripPace pace) {
    _update(state.draft.copyWith(pace: pace));
    _invalidateGeneration();
  }

  void setBudget(TripBudget budget) {
    _update(state.draft.copyWith(budget: budget));
    _invalidateGeneration();
  }

  void setNotes(String notes) {
    _update(state.draft.copyWith(notes: notes));
    _invalidateGeneration();
  }

  // Title is cosmetic and not fed to the generator, so it never invalidates.
  void setTitle(String title) => _update(state.draft.copyWith(title: title));

  int _defaultSizeFor(TripGroupKind kind) => switch (kind) {
    TripGroupKind.solo => 1,
    TripGroupKind.couple => 2,
    TripGroupKind.friends => 3,
    TripGroupKind.family => 4,
  };

  /// Editing a generation input after a skeleton was produced makes that
  /// skeleton stale; drop it so the user re-generates.
  void _invalidateGeneration() {
    if (state.phase == TripCreationPhase.generated) {
      emit(state.copyWith(phase: TripCreationPhase.editing, itinerary: const []));
    }
  }

  // --- Generation -----------------------------------------------------------

  Future<void> generate() async {
    emit(state.copyWith(phase: TripCreationPhase.generating, errorMessage: null));
    try {
      final plans = await _generator.generate(state.draft);
      emit(state.copyWith(phase: TripCreationPhase.generated, itinerary: plans));
    } catch (err) {
      _logger.w('Itinerary generation failed: $err');
      emit(
        state.copyWith(
          phase: TripCreationPhase.error,
          errorMessage: 'We couldn\u2019t build your itinerary. Please try again.',
        ),
      );
    }
  }

  // --- Submission (state mirror; persistence runs through TripCubit) --------

  void markSubmitting() => emit(state.copyWith(phase: TripCreationPhase.submitting, errorMessage: null));

  void markCreated(TripModel trip) => emit(
    state.copyWith(
      phase: TripCreationPhase.submitted,
      createdTrip: trip,
      draft: state.draft.copyWith(title: trip.title),
    ),
  );

  void markSubmitFailed() => emit(
    state.copyWith(phase: TripCreationPhase.error, errorMessage: 'Couldn\u2019t create your trip. Please try again.'),
  );
}
