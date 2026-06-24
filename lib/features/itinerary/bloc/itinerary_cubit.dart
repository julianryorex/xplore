import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/constants.dart';
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
class ItineraryCubit extends Cubit<ItineraryStates> with TripStreamMixin {
  ItineraryCubit([this._service, this._authService, ItineraryRepository? repository])
    : _repository = repository ?? ItineraryRepository(),
      super(const InitialItineraryState()) {
    _logger = createLogger('Itinerary');
    _tripSubscription = listenToTripState(_onTripStateChanged);
  }

  ItineraryService? _service;
  final AuthService? _authService;
  final ItineraryRepository _repository;
  late final Logger _logger;

  StreamSubscription<TripState>? _tripSubscription;
  StreamSubscription<ItineraryModel?>? _itinerarySubscription;
  String? _activeTripId;

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
      _safeEmit(LoadedItineraryState(itinerary: cached));
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

    _safeEmit(LoadedItineraryState(itinerary: itinerary));
    await _repository.cacheItinerary(tripId, itinerary);
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
        unawaited(loadForTrip(active.id));
      case TripEmpty() || TripError():
        _clear();
      case TripLoading():
        break;
    }
  }

  void _clear() {
    _activeTripId = null;
    unawaited(_itinerarySubscription?.cancel());
    _itinerarySubscription = null;
    _safeEmit(const EmptyItineraryState());
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
