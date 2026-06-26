import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';
import 'package:xplore/utilities/utilities.dart';

class TripCubit extends Cubit<TripState> with TripStreamMixin {
  TripCubit(this._tripService, this._authService, [this._itineraryService]) : super(const TripState.loading()) {
    _authSubscription = _authService.authStateChanges().listen(_onUserChanged);
  }

  final TripService _tripService;
  final AuthService _authService;

  /// Optional so existing trip tests construct the cubit without Firebase; when
  /// present, a new trip is seeded with a starter itinerary document.
  final ItineraryService? _itineraryService;

  final Logger _logger = createLogger('TripCubit');

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<TripModel>>? _tripsSubscription;

  /// A trip the user just joined/selected that should become active as soon as
  /// it appears in the trips stream (it may not be the newest trip).
  String? _pendingActiveTripId;

  String? get activeTripId => switch (state) {
    TripLoaded(:final active) => active.id,
    _ => null,
  };

  /// Marks [tripId] as the active trip. If it is already in the loaded set the
  /// switch is immediate; otherwise it is applied once the trips stream catches
  /// up (e.g. right after accepting an invite). Imports no other cubit.
  void setActiveTrip(String tripId) {
    _pendingActiveTripId = tripId;
    final current = state;
    if (current is TripLoaded) {
      final match = _firstWhereOrNull(current.all, tripId);
      if (match != null) {
        _pendingActiveTripId = null;
        _emitAndPublish(TripState.loaded(active: match, all: current.all));
      }
    }
  }

  TripModel? _firstWhereOrNull(List<TripModel> trips, String tripId) {
    for (final trip in trips) {
      if (trip.id == tripId) {
        return trip;
      }
    }
    return null;
  }

  /// Creates a minimally-specified trip from just a title (legacy/quick path).
  Future<void> createTrip(String title) async {
    await createTripFromDraft(TripDraft(title: title.trim(), destination: ''));
  }

  /// Creates a trip from the multi-step create flow's [draft] (FEAT-007),
  /// persisting destination/dates/preferences and seeding the itinerary with
  /// the generated [itinerary] skeleton. The created trip is marked active so
  /// the flow's invite step (and the rest of the app) sees it immediately.
  ///
  /// Returns the created [TripModel] so the caller can share/invite against it.
  Future<TripModel> createTripFromDraft(TripDraft draft, {List<DailyPlanModel> itinerary = const []}) async {
    final uid = _authService.currentUid;
    if (uid == null) {
      throw StateError('Cannot create a trip while unauthenticated.');
    }

    final resolvedTitle = draft.title.trim().isEmpty ? draft.suggestedTitle : draft.title.trim();
    if (resolvedTitle.isEmpty) {
      throw ArgumentError.value(draft.title, 'title', 'Trip title cannot be empty.');
    }

    final destination = draft.destination.trim();
    final trip = await _tripService.createTrip(
      resolvedTitle,
      uid,
      destination: destination.isEmpty ? null : destination,
      startDate: draft.datesAreFlexible ? null : draft.startDate,
      endDate: draft.datesAreFlexible ? null : draft.endDate,
      coverImageUrl: draft.coverImageUrl,
      preferences: draft.toPreferences(),
    );

    await _seedItinerary(trip, itinerary);
    setActiveTrip(trip.id);
    return trip;
  }

  /// Best-effort: a failed seed must not fail trip creation. The itinerary
  /// cubit lazily seeds the document on first load if this never lands.
  Future<void> _seedItinerary(TripModel trip, List<DailyPlanModel> dailyPlans) async {
    final service = _itineraryService;
    if (service == null) {
      return;
    }

    try {
      await service.seedItinerary(trip.id, trip.memberIds, dailyPlans: dailyPlans);
    } catch (err) {
      _logger.w('Failed to seed itinerary for trip ${trip.id}: $err');
    }
  }

  /// Re-attempts loading the trips stream for the current user. Used by the
  /// error banner's "Retry" action.
  void retry() {
    final uid = _authService.currentUid;
    if (uid == null) {
      _emitAndPublish(const TripState.empty());
      return;
    }
    _subscribeToTrips(uid);
  }

  /// Debug-only: forces the error state so the error banner can be previewed
  /// on-device. Cancels the live stream so it isn't immediately overwritten.
  void debugTriggerError() {
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
    _emitAndPublish(const TripState.error('Simulated failure for preview.'));
  }

  Future<void> _onUserChanged(User? user) async {
    await _tripsSubscription?.cancel();
    _tripsSubscription = null;

    if (user == null) {
      _emitAndPublish(const TripState.empty());
      return;
    }

    _subscribeToTrips(user.uid);
  }

  void _subscribeToTrips(String uid) {
    _tripsSubscription?.cancel();
    _emitAndPublish(const TripState.loading());
    _tripsSubscription = _tripService
        .fetchTrips(uid)
        .listen(
          (trips) {
            if (trips.isEmpty) {
              _emitAndPublish(const TripState.empty());
              return;
            }

            var active = trips.first;
            final desired = _pendingActiveTripId;
            if (desired != null) {
              final match = _firstWhereOrNull(trips, desired);
              if (match != null) {
                active = match;
                _pendingActiveTripId = null;
              }
            }

            _emitAndPublish(TripState.loaded(active: active, all: trips));
          },
          onError: (Object error) {
            _emitAndPublish(TripState.error(error.toString()));
          },
        );
  }

  void _emitAndPublish(TripState nextState) {
    if (isClosed) {
      return;
    }

    emit(nextState);
    pushTripEvent(nextState);
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    await _tripsSubscription?.cancel();
    return super.close();
  }
}
