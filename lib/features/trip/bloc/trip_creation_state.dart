import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

part '../../../generated/features/trip/bloc/trip_creation_state.freezed.dart';

/// The ordered buckets of the create-trip flow. Modelled as a list (see
/// [TripCreationCubit.steps]) so reordering, adding, or splitting a bucket is a
/// change to the list — not a rewrite of the flow.
enum CreateTripStep {
  destination,
  dates,
  group,
  vibe,
  generate,
  finishing,
  invite;

  /// Steps the user can move past without completing them — solo travellers
  /// must be able to sail through.
  bool get isSkippable => switch (this) {
    CreateTripStep.dates || CreateTripStep.vibe || CreateTripStep.invite => true,
    _ => false,
  };
}

/// Where the flow is in the generate/submit lifecycle, independent of which
/// [CreateTripStep] is on screen.
enum TripCreationPhase { editing, generating, generated, submitting, submitted, error }

@freezed
abstract class TripCreationState with _$TripCreationState {
  const factory TripCreationState({
    required TripDraft draft,
    required List<CreateTripStep> steps,
    @Default(0) int stepIndex,
    @Default(TripCreationPhase.editing) TripCreationPhase phase,
    @Default(<DailyPlanModel>[]) List<DailyPlanModel> itinerary,
    TripModel? createdTrip,
    String? errorMessage,
  }) = _TripCreationState;

  const TripCreationState._();

  CreateTripStep get currentStep => steps[stepIndex];

  bool get isFirstStep => stepIndex == 0;

  bool get isLastStep => stepIndex == steps.length - 1;

  double get progress => (stepIndex + 1) / steps.length;

  /// Whether the primary "Continue" affordance should be enabled for the
  /// current step.
  bool get canAdvance => switch (currentStep) {
    CreateTripStep.destination => draft.destination.trim().isNotEmpty,
    CreateTripStep.generate => phase == TripCreationPhase.generated,
    _ => true,
  };
}
