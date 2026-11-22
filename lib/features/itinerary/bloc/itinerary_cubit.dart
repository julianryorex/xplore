import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/auth/bloc/auth_cleanup_mixin.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/repository/itinerary_repository.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/utilities/utilities.dart';

part '../../../generated/features/itinerary/bloc/itinerary_cubit.freezed.dart';
part 'itinerary_states.dart';

/// Drives the home itinerary off the active trip.
///
/// Subscribes to [TripStreamMixin]; when a trip becomes active it loads any
/// cached copy (offline-first) and attaches a real-time Firestore listener via
/// [ItineraryService]. A missing document is lazily seeded so pre-existing trips
/// (or a failed create-time seed) self-heal on first load.
///
/// [ItineraryService] / [AuthService] are optional so the Firebase-free demo
/// path ([loadDemoItinerary]) used by tests and goldens can construct the cubit
/// with no arguments.
class ItineraryCubit extends Cubit<ItineraryStates> with TripStreamMixin, AuthCleanupMixin {
  ItineraryCubit([
    this._service,
    this._authService,
    ItineraryRepository? repository,
    this._retryBackoff = const Duration(seconds: 1),
  ]) : _repository = repository ?? ItineraryRepository(),
       super(const InitialItineraryState()) {
    _logger = createLogger('Itinerary');
    _tripSubscription = listenToTripState(_onTripStateChanged);
    // Optional auth service: the demo/golden path constructs the cubit without
    // one and never needs sign-out cleanup.
    final authService = _authService;
    if (authService != null) {
      bindAuthCleanup(authService);
    }
  }

  ItineraryService? _service;
  final AuthService? _authService;
  final ItineraryRepository _repository;

  /// Base delay before re-listening after a stream error; tests shorten it.
  final Duration _retryBackoff;
  late final Logger _logger;

  StreamSubscription<TripState>? _tripSubscription;
  StreamSubscription<ItineraryModel?>? _itinerarySubscription;
  String? _activeTripId;
  String? _activeTripCreatedBy;

  /// Editing is owner-only this pass: only the active trip's creator may write.
  /// The single gate for the in-app UI affordances ([LoadedItineraryState.canEdit])
  /// and every mutator below, on top of the authoritative Firestore rule; FEAT-024
  /// widens it to "owner or admin" here and in that rule.
  bool get _canEdit {
    final uid = _authService?.currentUid;
    return uid != null && uid == _activeTripCreatedBy;
  }

  /// Lazily created so the demo/test path never touches Firebase.
  ItineraryService get _itineraryService => _service ??= ItineraryService();

  // A trip that was just created becomes active from the local write, before
  // the server has it, so the read rule denies the first listen. Re-listening
  // shortly after succeeds; only a failure that persists is shown as an error.
  // The budget is reset only by caller-started loads, never by a snapshot:
  // offline persistence delivers a cached snapshot before every server denial,
  // which would otherwise refill the budget and re-listen forever.
  static const _maxAutoRetries = 2;
  int _autoRetries = 0;
  Timer? _retryTimer;

  // Bumped whenever a load starts or the cubit is cleared, so a load still
  // awaiting the cache knows it was superseded and must not attach a listener.
  int _loadGeneration = 0;

  // The edited plan while its save is in flight or has failed. The listener
  // keeps showing it over server snapshots, so an unsaved edit stays visible.
  List<DailyPlanModel>? _unsavedPlans;

  // Bumped per save so only the latest one settles the saving / failed state.
  int _saveSequence = 0;

  bool _debugFailNextSave = false;

  /// Loads the itinerary for [tripId]: cache first, then a live cloud listener.
  /// No-op while that trip is already loaded or loading.
  Future<void> loadForTrip(String tripId) async {
    if (_activeTripId == tripId && _itinerarySubscription != null) {
      return;
    }
    await _startLoad(tripId);
  }

  /// Re-attaches the itinerary listener for the active trip after a failure.
  Future<void> retry() async {
    final tripId = _activeTripId;
    if (tripId == null) {
      return;
    }
    await _startLoad(tripId);
  }

  Future<void> _startLoad(String tripId) {
    _autoRetries = 0;
    return _listen(tripId, isAutoRetry: false);
  }

  Future<void> _listen(String tripId, {required bool isAutoRetry}) async {
    _abandonPendingLoads();
    final generation = _loadGeneration;
    _activeTripId = tripId;
    // Emit before the first await: TripCubit has already emitted the new trip,
    // and listeners must not pair it with the previous trip's days meanwhile.
    // An auto retry stays on the same trip, so it keeps a shown itinerary.
    if (!isAutoRetry || state is! LoadedItineraryState) {
      _safeEmit(const LoadingItineraryState());
    }
    await _itinerarySubscription?.cancel();
    _itinerarySubscription = null;

    final cached = await _repository.loadFromCache(tripId);
    if (isClosed || generation != _loadGeneration) {
      return;
    }
    if (cached != null && state is! LoadedItineraryState) {
      _safeEmit(LoadedItineraryState(itinerary: cached, canEdit: _canEdit));
    }

    _itinerarySubscription = _itineraryService
        .watchItinerary(tripId)
        .listen(
          (itinerary) => _onItinerarySnapshot(tripId, itinerary),
          onError: (Object error) => _onItineraryError(tripId, generation, error),
        );
  }

  void _onItineraryError(String tripId, int generation, Object error) {
    _logger.w('Itinerary stream error for $tripId: $error');
    if (generation != _loadGeneration) {
      return;
    }
    if (_isTransientDenial(error) && _autoRetries < _maxAutoRetries) {
      _autoRetries++;
      _retryTimer = Timer(_retryBackoff * _autoRetries, () => unawaited(_listen(tripId, isAutoRetry: true)));
      return;
    }
    _safeEmit(ErrorItineraryState(error.toString()));
  }

  // Only the not-yet-committed-trip denial clears up on its own; anything else
  // (bad data, failed-precondition, ...) would fail the same way again.
  static bool _isTransientDenial(Object error) => error is FirebaseException && error.code == 'permission-denied';

  void _abandonPendingLoads() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _loadGeneration++;
  }

  Future<void> _onItinerarySnapshot(String tripId, ItineraryModel? itinerary) async {
    // Ignore late events from a trip we've since switched away from.
    if (_activeTripId != tripId) {
      return;
    }

    if (itinerary == null) {
      await _seedIfPossible(tripId);
      return;
    }

    final current = state;
    final unsaved = _unsavedPlans;
    if (unsaved != null && current is LoadedItineraryState && (current.isSaving || current.saveFailure != null)) {
      _safeEmit(
        current.copyWith(
          itinerary: itinerary.copyWith(dailyPlans: unsaved),
          canEdit: _canEdit,
        ),
      );
    } else {
      _unsavedPlans = null;
      _safeEmit(LoadedItineraryState(itinerary: itinerary, canEdit: _canEdit));
    }
    await _repository.cacheItinerary(tripId, itinerary);
  }

  /// Toggles the `completed` flag on the stop at [stopIndex] of day [dayIndex].
  Future<void> toggleLocationCompleted(int dayIndex, int stopIndex) {
    return _saveEdit(
      ItineraryEdit.completeStop,
      (plans) => _withStops(plans, dayIndex, (stops) {
        if (!_inRange(stopIndex, stops)) {
          return null;
        }
        return [...stops]..[stopIndex] = stops[stopIndex].copyWith(completed: !stops[stopIndex].completed);
      }),
    );
  }

  /// Appends [stop] to day [dayIndex], recording [author] as who added it.
  Future<void> addLocation(int dayIndex, LocationPlanModel stop, {ChangeAuthorType author = ChangeAuthorType.person}) {
    final stopIndex = _stopsOf(dayIndex)?.length;
    return _saveEdit(
      ItineraryEdit.addStop,
      (plans) => _withStops(plans, dayIndex, (stops) {
        return [...stops, stop.copyWith(lastChange: _change(ItineraryChangeAction.added, author))];
      }),
      dayIndex: dayIndex,
      stopIndex: stopIndex,
    );
  }

  /// Replaces the stop at [stopIndex] of day [dayIndex] with [stop].
  Future<void> updateLocation(
    int dayIndex,
    int stopIndex,
    LocationPlanModel stop, {
    ChangeAuthorType author = ChangeAuthorType.person,
  }) {
    return _saveEdit(
      ItineraryEdit.updateStop,
      (plans) => _withStops(plans, dayIndex, (stops) {
        if (!_inRange(stopIndex, stops)) {
          return null;
        }
        return [...stops]..[stopIndex] = stop.copyWith(lastChange: _change(ItineraryChangeAction.edited, author));
      }),
      dayIndex: dayIndex,
      stopIndex: stopIndex,
    );
  }

  /// Deletes the stop at [stopIndex] of day [dayIndex]. The removal is recorded on the day.
  Future<void> removeLocation(int dayIndex, int stopIndex, {ChangeAuthorType author = ChangeAuthorType.person}) {
    return _saveEdit(
      ItineraryEdit.removeStop,
      (plans) => _withStops(plans, dayIndex, dayChange: _change(ItineraryChangeAction.stopRemoved, author), (stops) {
        if (!_inRange(stopIndex, stops)) {
          return null;
        }
        return [...stops]..removeAt(stopIndex);
      }),
    );
  }

  /// Moves the stop at [fromIndex] of day [dayIndex] so it ends up at [toIndex].
  Future<void> reorderLocations(
    int dayIndex,
    int fromIndex,
    int toIndex, {
    ChangeAuthorType author = ChangeAuthorType.person,
  }) {
    return _saveEdit(
      ItineraryEdit.reorderStops,
      (plans) => _withStops(plans, dayIndex, dayChange: _change(ItineraryChangeAction.stopsReordered, author), (stops) {
        if (!_inRange(fromIndex, stops) || !_inRange(toIndex, stops) || fromIndex == toIndex) {
          return null;
        }
        final reordered = [...stops];
        reordered.insert(toIndex, reordered.removeAt(fromIndex));
        return reordered;
      }),
    );
  }

  /// Adds an empty, untitled day after [afterIndex], or at the end when null.
  /// It starts in the same place as the day before it.
  Future<void> addDay({int? afterIndex, ChangeAuthorType author = ChangeAuthorType.person}) {
    return _saveEdit(ItineraryEdit.addDay, (plans) {
      if (afterIndex != null && !_inRange(afterIndex, plans)) {
        return null;
      }
      final insertAt = afterIndex == null ? plans.length : afterIndex + 1;
      final day = DailyPlanModel(
        title: '',
        location: insertAt == 0 ? '' : plans[insertAt - 1].location,
        plan: const PlanModel(favorited: [], locations: []),
        lastChange: _change(ItineraryChangeAction.added, author),
      );
      return [...plans]..insert(insertAt, day);
    });
  }

  /// Sets the title of day [dayIndex]. A blank title falls back to the day's date in the UI.
  Future<void> renameDay(int dayIndex, String title, {ChangeAuthorType author = ChangeAuthorType.person}) {
    return _saveEdit(ItineraryEdit.renameDay, (plans) {
      if (!_inRange(dayIndex, plans) || plans[dayIndex].title == title.trim()) {
        return null;
      }
      final day = plans[dayIndex];
      final renamed = day.copyWith(title: title.trim(), lastChange: _change(ItineraryChangeAction.renamed, author));
      return [...plans]..[dayIndex] = renamed;
    });
  }

  /// Deletes day [dayIndex] together with its stops; later days move up.
  /// Who removed it is not recorded: change records live on the days themselves.
  Future<void> removeDay(int dayIndex) {
    return _saveEdit(ItineraryEdit.removeDay, (plans) {
      return _inRange(dayIndex, plans) ? ([...plans]..removeAt(dayIndex)) : null;
    });
  }

  /// Writes the edit left unsaved by a failed save again.
  Future<void> retrySave() async {
    final current = state;
    final tripId = _activeTripId;
    final plans = _unsavedPlans;
    if (current is! LoadedItineraryState || tripId == null || plans == null || !_canEdit) {
      return;
    }
    final failure = current.saveFailure;
    if (failure != null) {
      await _writePlans(tripId, plans, failure);
    }
  }

  /// Developer tools only: makes the next itinerary save fail, to preview the save-failed state.
  void debugFailNextSave() => _debugFailNextSave = true;

  /// Applies [transform] to the shown plan and saves the result. Gated on
  /// [_canEdit], the one place FEAT-024 widens editing to admins. A null
  /// result from [transform] means there is nothing to change.
  Future<void> _saveEdit(
    ItineraryEdit edit,
    List<DailyPlanModel>? Function(List<DailyPlanModel> plans) transform, {
    int? dayIndex,
    int? stopIndex,
  }) async {
    final current = state;
    final tripId = _activeTripId;
    if (current is! LoadedItineraryState || tripId == null) {
      return;
    }
    if (!_canEdit) {
      _logger.w('Ignoring itinerary edit: not allowed to edit this trip');
      return;
    }
    final plans = transform(current.itinerary.dailyPlans);
    if (plans == null) {
      return;
    }
    await _writePlans(tripId, plans, ItinerarySaveFailure(edit: edit, dayIndex: dayIndex, stopIndex: stopIndex));
  }

  /// Shows [plans] at once, then writes the whole `daily_plans` array. The
  /// cubit never writes the cache: the snapshot listener does, with what the
  /// server holds (see the FEAT-006 sync contract).
  Future<void> _writePlans(String tripId, List<DailyPlanModel> plans, ItinerarySaveFailure onFailure) async {
    final current = state;
    if (current is! LoadedItineraryState) {
      return;
    }
    final sequence = ++_saveSequence;
    _unsavedPlans = plans;
    _safeEmit(
      current.copyWith(itinerary: current.itinerary.copyWith(dailyPlans: plans), isSaving: true, saveFailure: null),
    );

    var failed = false;
    try {
      if (_debugFailNextSave) {
        _debugFailNextSave = false;
        throw StateError('Save failure requested from developer tools');
      }
      await _itineraryService.writeDailyPlans(tripId, plans);
    } catch (err) {
      _logger.w('Failed to save itinerary edit (${onFailure.edit.name}) for $tripId: $err');
      failed = true;
    }

    // A newer edit, a trip switch or a reload owns the state now.
    final latest = state;
    if (sequence != _saveSequence || _activeTripId != tripId || latest is! LoadedItineraryState) {
      return;
    }
    if (failed) {
      _safeEmit(latest.copyWith(isSaving: false, saveFailure: onFailure));
    } else {
      _unsavedPlans = null;
      _safeEmit(latest.copyWith(isSaving: false));
    }
  }

  List<LocationPlanModel>? _stopsOf(int dayIndex) {
    final current = state;
    if (current is! LoadedItineraryState || !_inRange(dayIndex, current.itinerary.dailyPlans)) {
      return null;
    }
    return current.itinerary.dailyPlans[dayIndex].plan.locations;
  }

  /// [plans] with the stops of day [dayIndex] replaced by [transform]'s result,
  /// or null when the day is out of range or [transform] has nothing to change.
  List<DailyPlanModel>? _withStops(
    List<DailyPlanModel> plans,
    int dayIndex,
    List<LocationPlanModel>? Function(List<LocationPlanModel> stops) transform, {
    ItineraryChangeModel? dayChange,
  }) {
    if (!_inRange(dayIndex, plans)) {
      return null;
    }
    final day = plans[dayIndex];
    final stops = transform(day.plan.locations);
    if (stops == null) {
      return null;
    }
    final updated = day.copyWith(
      plan: day.plan.copyWith(locations: stops),
      lastChange: dayChange ?? day.lastChange,
    );
    return [...plans]..[dayIndex] = updated;
  }

  static bool _inRange(int index, List<Object?> list) => index >= 0 && index < list.length;

  ItineraryChangeModel _change(ItineraryChangeAction action, ChangeAuthorType author) {
    return ItineraryChangeModel(
      action: action,
      authorType: author,
      authorId: author == ChangeAuthorType.person ? (_authService?.currentUid ?? '') : '',
      at: DateTime.now().toUtc(),
    );
  }

  /// Best-effort lazy seed; the listener re-fires with the written doc.
  Future<void> _seedIfPossible(String tripId) async {
    try {
      final uid = _authService?.currentUid;
      await _itineraryService.seedItinerary(tripId, [?uid]);
    } catch (err) {
      _logger.w('Failed to seed itinerary for $tripId: $err');
      if (_activeTripId == tripId) {
        _safeEmit(const EmptyItineraryState());
      }
    }
  }

  void _onTripStateChanged(TripState tripState) {
    switch (tripState) {
      case TripLoaded(:final active):
        _activeTripCreatedBy = active.createdBy;
        unawaited(loadForTrip(active.id));
      case TripEmpty() || TripError():
        _clear();
      case TripLoading():
        break;
    }
  }

  void _clear() {
    _abandonPendingLoads();
    _unsavedPlans = null;
    _activeTripId = null;
    _activeTripCreatedBy = null;
    unawaited(_itinerarySubscription?.cancel());
    _itinerarySubscription = null;
    _safeEmit(const EmptyItineraryState());
  }

  /// Sign-out cleanup (via [AuthCleanupMixin]): detach the live listener, reset
  /// in-memory state, and drop the on-disk itinerary cache (a single box keyed
  /// by trip) so no trip's cached plan lingers for the next account.
  @override
  Future<void> onSignedOut() async {
    _clear();
    await _repository.reset();
  }

  void _safeEmit(ItineraryStates next) {
    if (isClosed) {
      return;
    }
    emit(next);
  }

  /// Loads the bundled Tokyo demo itinerary. Retained for
  /// `test/itinerary_demo_smoke_test.dart`, the golden test, and the in-app
  /// debug button; never used on the production trip path.
  @visibleForTesting
  Future<void> loadDemoItinerary() async {
    final Map<String, dynamic> demoData = await loadJsonAsset('assets/demo/itinerary.json');

    final itineraryList = demoData['itineraries'] as List<dynamic>;
    final itinerary = itineraryList.firstWhere((el) => el.keys.first == itineraryId) as Map<String, dynamic>;

    final itineraryModel = ItineraryModel.fromJson(itinerary[itineraryId]);
    _safeEmit(LoadedItineraryState(itinerary: itineraryModel));
  }

  @override
  Future<void> close() {
    // Not awaited: awaiting the broadcast trip-stream cancel deadlocks inside a
    // `testWidgets` FakeAsync zone (the itinerary golden test), and cancel is
    // effectively immediate for a broadcast subscription anyway.
    _abandonPendingLoads();
    unawaited(_tripSubscription?.cancel() ?? Future<void>.value());
    unawaited(_itinerarySubscription?.cancel() ?? Future<void>.value());
    return super.close();
  }
}
