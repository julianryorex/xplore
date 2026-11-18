import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/models/trip_plan.dart';

part '../../../generated/features/trip/bloc/trip_creation_state.freezed.dart';

/// Most places one trip can have.
const maxTripStops = 8;

/// The ordered steps of the create-trip flow. Modelled as a list (see
/// [TripCreationState.steps]) so reordering, adding, or splitting a step is a
/// change to the list, not a rewrite of the flow. [invite] follows creation.
enum CreateTripStep {
  where,
  when,
  whoAndVibe,
  plan,
  invite;

  /// Steps whose every input has a sensible default, so the UI may offer
  /// "Skip for now".
  bool get isSkippable => switch (this) {
    CreateTripStep.whoAndVibe || CreateTripStep.invite => true,
    _ => false,
  };
}

/// Why the current step's primary action is disabled.
enum CreateTripBlocker {
  /// Where: no place added yet.
  noStops,

  /// When (or later): the nights do not add up; read
  /// [TripDraft.nightsAllocation] for the specific [NightsIssue] and counts.
  nightsInvalid,

  /// Plan: the trip name is longer than [maxTripTitleLength].
  titleTooLong,

  /// Plan: the trip is being created.
  submitting,
}

/// Where the flow is in the submit lifecycle, independent of which
/// [CreateTripStep] is on screen.
enum TripCreationPhase { editing, submitting, submitted, error }

@freezed
abstract class TripCreationState with _$TripCreationState {
  const factory TripCreationState({
    required TripDraft draft,

    /// The draft the flow started from; [hasUnsavedInput] compares against it.
    required TripDraft initialDraft,
    required List<CreateTripStep> steps,
    @Default(0) int stepIndex,
    @Default(TripCreationPhase.editing) TripCreationPhase phase,

    /// The stub plan, built when the plan step is entered. Null before that and
    /// whenever stops, nights or dates changed since (rebuilt on the next visit).
    TripPlan? plan,
    TripModel? createdTrip,
    String? errorMessage,
  }) = _TripCreationState;

  const TripCreationState._();

  CreateTripStep get currentStep => steps[stepIndex];

  bool get isFirstStep => stepIndex == 0;

  bool get isLastStep => stepIndex == steps.length - 1;

  double get progress => (stepIndex + 1) / steps.length;

  /// Whether back navigation is possible: not on the first step, and not once
  /// the trip is being or has been created.
  bool get canGoBack => !isFirstStep && phase != TripCreationPhase.submitting && phase != TripCreationPhase.submitted;

  /// Whether another place may be added (at most [maxTripStops]).
  bool get canAddStop => draft.stops.length < maxTripStops;

  /// True once the user entered anything and the trip is not created yet, so
  /// the UI should confirm before discarding the flow.
  bool get hasUnsavedInput =>
      phase != TripCreationPhase.submitting && phase != TripCreationPhase.submitted && draft != initialDraft;

  /// The plan's days, the shape the itinerary is seeded with; empty without a plan.
  List<DailyPlanModel> get itinerary => plan?.days ?? const [];

  /// Why the current step cannot advance (the primary button is disabled), or
  /// null when it can. On the plan step "advance" means "Create trip".
  CreateTripBlocker? get advanceBlocker => switch (currentStep) {
    CreateTripStep.where => draft.stops.isEmpty ? CreateTripBlocker.noStops : null,
    CreateTripStep.when => _tripShapeBlocker,
    CreateTripStep.whoAndVibe || CreateTripStep.invite => null,
    CreateTripStep.plan =>
      phase == TripCreationPhase.submitting
          ? CreateTripBlocker.submitting
          : _tripShapeBlocker ??
                (draft.effectiveTitle.length > maxTripTitleLength ? CreateTripBlocker.titleTooLong : null),
  };

  /// Whether the current step's primary action is enabled; see [advanceBlocker].
  bool get canAdvance => advanceBlocker == null;

  CreateTripBlocker? get _tripShapeBlocker {
    if (draft.stops.isEmpty) {
      return CreateTripBlocker.noStops;
    }
    return draft.isNightsAllocationValid ? null : CreateTripBlocker.nightsInvalid;
  }
}
