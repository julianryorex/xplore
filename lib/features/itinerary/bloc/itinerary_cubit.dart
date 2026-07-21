import 'dart:async';

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
  ItineraryCubit([this._service, this._authService, ItineraryRepository? repository])
    : _repository = repository ?? ItineraryRepository(),
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
  late final Logger _logger;

  StreamSubscription<TripState>? _tripSubscription;
  StreamSubscription<ItineraryModel?>? _itinerarySubscription;
  String? _activeTripId;
  String? _activeTripCreatedBy;

  /// Editing is owner-only this pass: only the active trip's creator may write.
  /// Guards both the in-app UI affordances ([LoadedItineraryState.canEdit]) and
  /// the mutators below, on top of the authoritative Firestore rule.
  bool get _canEdit {
    final uid = _authService?.currentUid;
    return uid != null && uid == _activeTripCreatedBy;
  }

  /// Lazily created so the demo/test path never touches Firebase.
  ItineraryService get _itineraryService => _service ??= ItineraryService();

  /// Loads the itinerary for [tripId]: cache first, then a live cloud listener.
  Future<void> loadForTrip(String tripId) async {
    if (_activeTripId == tripId && _itinerarySubscription != null) {
      return;
    }

    _activeTripId = tripId;
    await _itinerarySubscription?.cancel();
    _itinerarySubscription = null;

    _safeEmit(const LoadingItineraryState());

    final cached = await _repository.loadFromCache(tripId);
    if (cached != null && _activeTripId == tripId && state is! LoadedItineraryState) {
      _safeEmit(LoadedItineraryState(itinerary: cached, canEdit: _canEdit));
    }

    _itinerarySubscription = _itineraryService
        .watchItinerary(tripId)
        .listen(
          (itinerary) => _onItinerarySnapshot(tripId, itinerary),
          onError: (Object error) {
            _logger.w('Itinerary stream error for $tripId: $error');
            if (_activeTripId == tripId) {
              _safeEmit(ErrorItineraryState(error.toString()));
            }
          },
        );
  }

  /// Re-attaches the itinerary listener for the active trip after a failure.
  /// The errored subscription is still set, so reset the active id to force a
  /// fresh load past [loadForTrip]'s early-return guard.
  Future<void> retry() async {
    final tripId = _activeTripId;
    if (tripId == null) {
      return;
    }
    _activeTripId = null;
    await loadForTrip(tripId);
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

    _safeEmit(LoadedItineraryState(itinerary: itinerary, canEdit: _canEdit));
    await _repository.cacheItinerary(tripId, itinerary);
  }

  /// Toggles the `completed` flag on the stop at [locationIndex] within the day
  /// at [dayIndex]. Owner-only: no-ops for non-owners and when no itinerary is
  /// loaded. Writes the whole `daily_plans` array to Firestore only — the
  /// snapshot listener echoes the committed value back into state + cache (the
  /// cubit never writes Hive directly; see the FEAT-006 sync contract).
  Future<void> toggleLocationCompleted(int dayIndex, int locationIndex) async {
    final current = state;
    final tripId = _activeTripId;
    if (current is! LoadedItineraryState || tripId == null) {
      return;
    }
    if (!_canEdit) {
      _logger.w('Ignoring itinerary edit: not the trip owner');
      return;
    }

    final plans = current.itinerary.dailyPlans;
    if (dayIndex < 0 || dayIndex >= plans.length) {
      return;
    }
    final day = plans[dayIndex];
    final locations = day.plan.locations;
    if (locationIndex < 0 || locationIndex >= locations.length) {
      return;
    }

    final location = locations[locationIndex];
    final updatedLocations = [...locations]..[locationIndex] = location.copyWith(completed: !location.completed);
    final updatedPlans = [...plans]..[dayIndex] = day.copyWith(plan: day.plan.copyWith(locations: updatedLocations));

    try {
      await _itineraryService.writeDailyPlans(tripId, updatedPlans);
    } catch (err) {
      // Firestore offline persistence queues the write, so a hard failure here
      // is rare; the listener re-emits the server truth either way.
      _logger.w('Failed to toggle stop completion for $tripId: $err');
    }
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
    unawaited(_tripSubscription?.cancel() ?? Future<void>.value());
    unawaited(_itinerarySubscription?.cancel() ?? Future<void>.value());
    return super.close();
  }
}
