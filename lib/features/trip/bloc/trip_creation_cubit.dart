import 'package:collection/collection.dart';
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

  /// Undoes [removeStop] for the stop with [id], given [stopsBefore], the stops
  /// as they were just before the removal. Every stop gets its earlier nights
  /// back when the other stops are unchanged since; otherwise the stop returns
  /// to its old slot (clamped) and exact-date nights re-split evenly.
  void restoreStop(String id, {required List<TripStop> stopsBefore}) {
    final index = stopsBefore.indexWhere((stop) => stop.id == id);
    final current = state.draft.stops;
    if (index < 0 || !state.canAddStop || current.any((stop) => stop.id == id)) {
      return;
    }
    final othersUnchanged = const ListEquality<String>().equals(
      [
        for (final stop in stopsBefore)
          if (stop.id != id) stop.id,
      ],
      [for (final stop in current) stop.id],
    );
    if (othersUnchanged) {
      _updateTripShape(state.draft.copyWith(stops: stopsBefore));
      return;
    }
    final restored = [...current]..insert(index.clamp(0, current.length), stopsBefore[index]);
    _updateTripShape(_resplitIfExact(state.draft.copyWith(stops: restored)));
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

  /// Switches to exact dates (date-only; swapped if reversed). Hand-set nights
  /// are kept when they already add up to the new dates, or when the dates keep
  /// the trip's length; otherwise the nights re-split evenly.
  void setExactDates(DateTime start, DateTime end) {
    var from = nights.dateOnly(start);
    var to = nights.dateOnly(end);
    if (to.isBefore(from)) {
      (from, to) = (to, from);
    }
    final previousTarget = state.draft.targetNights;
    final updated = state.draft.copyWith(datesAreFlexible: false, startDate: from, endDate: to);
    final target = updated.targetNights;
    final keepNights = target == previousTarget || target == updated.assignedNights;
    _updateTripShape(keepNights ? updated : _resplitIfExact(updated));
  }

  /// Switches to flexible dates, where the stops' nights are the trip length.
  /// Current nights are kept, raised to at least one per stop.
  void setFlexible() {
    final stops = [for (final stop in state.draft.stops) stop.nights < 1 ? stop.copyWith(nights: 1) : stop];
    _updateTripShape(state.draft.copyWith(datesAreFlexible: true, stops: stops));
  }

  /// Sets one stop's nights (clamped to 1..[nights.maxTripNights], or from 0 on
  /// a same-day trip) without touching any other stop; validation reports a
  /// mismatch with exact dates.
  void setStopNights(String id, int value) {
    final minimum = state.draft.targetNights == 0 ? 0 : 1;
    final clamped = value.clamp(minimum, nights.maxTripNights);
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
