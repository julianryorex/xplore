import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart' as nights;
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';
import 'package:xplore/features/trip/services/stub_plan_builder.dart';

/// Drives the four-step create-trip flow (where, when, who and vibe, plan) and
/// the invite step after it. Holds a single [TripDraft], keeps its nights
/// consistent as places and dates change, and builds the stub plan on entering
/// the plan step. Persistence runs through `TripCubit.createTripFromDraft`.
class TripCreationCubit extends Cubit<TripCreationState> {
  /// [initialNotes] seeds the draft's free-text notes, for callers that already
  /// collected a description of the trip (the home screen's text field).
  TripCreationCubit({List<CreateTripStep>? steps, String initialNotes = '', this._catalog = placeCatalog})
    : super(_initialState(steps ?? CreateTripStep.values, TripDraft(notes: initialNotes)));

  static TripCreationState _initialState(List<CreateTripStep> steps, TripDraft draft) =>
      TripCreationState(draft: draft, initialDraft: draft, steps: steps);

  final PlaceCatalog _catalog;

  // --- Step navigation ------------------------------------------------------

  /// Moves to the next step when [TripCreationState.canAdvance]. Entering the
  /// plan step builds the plan if it is missing. Leaving the plan step needs a
  /// created trip ([markCreated]); "Create trip" itself runs through TripCubit.
  void next() {
    if (state.isLastStep || !state.canAdvance) {
      return;
    }
    if (state.currentStep == CreateTripStep.plan && state.createdTrip == null) {
      return;
    }
    final nextIndex = state.stepIndex + 1;
    final enteringPlan = state.steps[nextIndex] == CreateTripStep.plan;
    emit(
      state.copyWith(
        stepIndex: nextIndex,
        plan: enteringPlan ? (state.plan ?? buildStubPlan(state.draft, catalog: _catalog)) : state.plan,
      ),
    );
  }

  /// Moves to the previous step when [TripCreationState.canGoBack].
  void back() {
    if (!state.canGoBack) {
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex - 1));
  }

  // --- Where ----------------------------------------------------------------

  /// Appends [place] as the last stop. Ignored when it is already on the trip or
  /// the trip has [maxTripStops]. Exact-date trips re-split their nights evenly;
  /// flexible trips give the new stop [nights.defaultFlexibleNights].
  void addStop(CatalogPlace place) {
    final stops = state.draft.stops;
    if (!state.canAddStop || stops.any((stop) => stop.id == place.id)) {
      return;
    }
    final added = [...stops, place.toStop(nights: nights.defaultFlexibleNights)];
    _updateTripShape(_resplitIfExact(state.draft.copyWith(stops: added)));
  }

  /// Removes the stop with [id]; exact-date trips re-split their nights evenly.
  void removeStop(String id) {
    final remaining = state.draft.stops.where((stop) => stop.id != id).toList();
    if (remaining.length == state.draft.stops.length) {
      return;
    }
    _updateTripShape(_resplitIfExact(state.draft.copyWith(stops: remaining)));
  }

  /// Moves a stop with ReorderableListView semantics: [newIndex] is the slot
  /// before removal, so moving down passes one past the target. Nights travel
  /// with their stop.
  void reorderStops(int oldIndex, int newIndex) {
    final stops = [...state.draft.stops];
    if (oldIndex < 0 || oldIndex >= stops.length) {
      return;
    }
    final target = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, stops.length - 1);
    if (target == oldIndex) {
      return;
    }
    stops.insert(target, stops.removeAt(oldIndex));
    _updateTripShape(state.draft.copyWith(stops: stops));
  }

  // --- When -----------------------------------------------------------------

  /// Switches to exact dates (date-only; swapped if reversed). Nights re-split
  /// evenly when the trip's night count or date mode changes; shifting the same
  /// length to other dates keeps hand-tuned nights.
  void setExactDates(DateTime start, DateTime end) {
    var from = nights.dateOnly(start);
    var to = nights.dateOnly(end);
    if (to.isBefore(from)) {
      (from, to) = (to, from);
    }
    final previousTarget = state.draft.targetNights;
    final updated = state.draft.copyWith(datesAreFlexible: false, startDate: from, endDate: to);
    _updateTripShape(updated.targetNights == previousTarget ? updated : _resplitIfExact(updated));
  }

  /// Switches to flexible dates, where the stops' nights are the trip length.
  /// Current nights are kept, raised to at least one per stop.
  void setFlexible() {
    final stops = [for (final stop in state.draft.stops) stop.nights < 1 ? stop.copyWith(nights: 1) : stop];
    _updateTripShape(state.draft.copyWith(datesAreFlexible: true, stops: stops));
  }

  /// Sets one stop's nights (clamped to 1..[nights.maxTripNights]) without
  /// touching any other stop; validation reports a mismatch with exact dates.
  void setStopNights(String id, int value) {
    final clamped = value.clamp(1, nights.maxTripNights);
    final stops = [for (final stop in state.draft.stops) stop.id == id ? stop.copyWith(nights: clamped) : stop];
    _updateTripShape(state.draft.copyWith(stops: stops));
  }

  /// Spreads the nights evenly over the stops: the exact dates' total, or for
  /// flexible dates the current total (keeping the trip length).
  void splitNightsEvenly() {
    final draft = state.draft;
    _updateTripShape(_withSplit(draft, draft.targetNights ?? draft.assignedNights));
  }

  // --- Who and vibe ---------------------------------------------------------

  /// Sets the group kind, with [size] or that kind's default group size.
  void setGroup(TripGroupKind kind, {int? size}) {
    _updateDraft(state.draft.copyWith(groupKind: kind, groupSize: size ?? _defaultSizeFor(kind)));
  }

  /// Sets the group size, clamped to 1..50.
  void setGroupSize(int size) => _updateDraft(state.draft.copyWith(groupSize: size.clamp(1, 50)));

  /// Adds [interest] when absent, removes it when present.
  void toggleInterest(TripInterest interest) {
    final next = Set<TripInterest>.from(state.draft.interests);
    if (!next.add(interest)) {
      next.remove(interest);
    }
    _updateDraft(state.draft.copyWith(interests: next));
  }

  void setPace(TripPace pace) => _updateDraft(state.draft.copyWith(pace: pace));

  void setBudget(TripBudget budget) => _updateDraft(state.draft.copyWith(budget: budget));

  void setNotes(String notes) => _updateDraft(state.draft.copyWith(notes: notes));

  // --- Plan -----------------------------------------------------------------

  /// Sets the typed trip name; blank falls back to [TripDraft.suggestedTitle].
  void setTitle(String title) => _updateDraft(state.draft.copyWith(title: title));

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
    state.copyWith(phase: TripCreationPhase.error, errorMessage: 'Couldn’t create your trip. Please try again.'),
  );

  // --- TEMPORARY shims for the old 7-step screens ---------------------------
  // Remove with lib/features/trip/presentation/create_trip/ once the new
  // screens land. New code must use addStop / setFlexible / setStopNights.

  /// TEMPORARY: replaces the stops with the single place named [value]: its
  /// catalog entry when one matches exactly, otherwise an uncatalogued stop.
  void setDestination(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      _updateTripShape(_resplitIfExact(state.draft.copyWith(stops: const [])));
      return;
    }
    final folded = foldForSearch(name);
    final match = _catalog.search(name).where((place) => foldForSearch(place.name) == folded).firstOrNull;
    final stop =
        match?.toStop(nights: nights.defaultFlexibleNights) ??
        TripStop(id: 'custom:$folded', name: name, country: '', latitude: 0, longitude: 0);
    _updateTripShape(_resplitIfExact(state.draft.copyWith(stops: [stop])));
  }

  /// TEMPORARY: switches to flexible dates lasting [days] days, split evenly.
  void setFlexibleDuration(int days) {
    final draft = state.draft.copyWith(datesAreFlexible: true);
    _updateTripShape(_withSplit(draft, (days - 1).clamp(draft.stops.length, nights.maxTripNights)));
  }

  // --- Internals ------------------------------------------------------------

  int _defaultSizeFor(TripGroupKind kind) => switch (kind) {
    TripGroupKind.solo => 1,
    TripGroupKind.couple => 2,
    TripGroupKind.friends => 3,
    TripGroupKind.family => 4,
  };

  TripDraft _withSplit(TripDraft draft, int total) {
    final split = nights.splitNightsEvenly(total, draft.stops.length);
    return draft.copyWith(stops: [for (var i = 0; i < split.length; i++) draft.stops[i].copyWith(nights: split[i])]);
  }

  /// Exact dates fix the total, so a changed set of stops is re-split against
  /// it; flexible trips have no total to split.
  TripDraft _resplitIfExact(TripDraft draft) {
    final target = draft.targetNights;
    return target == null ? draft : _withSplit(draft, target);
  }

  /// Ignores edits once the trip is being or has been created.
  bool get _isLocked => state.phase == TripCreationPhase.submitting || state.phase == TripCreationPhase.submitted;

  void _updateDraft(TripDraft draft) {
    if (_isLocked) {
      return;
    }
    emit(state.copyWith(draft: draft));
  }

  /// For edits to stops, nights or dates: the plan no longer matches. It is
  /// rebuilt right away while the plan step is showing (so the screen never
  /// loses its plan), otherwise on the next visit.
  void _updateTripShape(TripDraft draft) {
    if (_isLocked) {
      return;
    }
    final rebuildNow = state.currentStep == CreateTripStep.plan && draft.isNightsAllocationValid;
    emit(
      state.copyWith(
        draft: draft,
        plan: rebuildNow ? buildStubPlan(draft, catalog: _catalog) : null,
      ),
    );
  }
}
