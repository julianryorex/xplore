import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

class TripCubit extends Cubit<TripState> with TripStreamMixin {
  TripCubit(this._tripService, this._authService) : super(const TripState.loading()) {
    _authSubscription = _authService.authStateChanges().listen(_onUserChanged);
  }

  final TripService _tripService;
  final AuthService _authService;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<TripModel>>? _tripsSubscription;

  String? get activeTripId => switch (state) {
    TripLoaded(:final active) => active.id,
    _ => null,
  };

  Future<void> createTrip(String title) async {
    final uid = _authService.currentUid;
    if (uid == null) {
      throw StateError('Cannot create a trip while unauthenticated.');
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Trip title cannot be empty.');
    }

    await _tripService.createTrip(trimmedTitle, uid);
  }

  Future<void> _onUserChanged(User? user) async {
    await _tripsSubscription?.cancel();
    _tripsSubscription = null;

    if (user == null) {
      _emitAndPublish(const TripState.empty());
      return;
    }

    _emitAndPublish(const TripState.loading());
    _tripsSubscription = _tripService
        .fetchTrips(user.uid)
        .listen(
          (trips) {
            if (trips.isEmpty) {
              _emitAndPublish(const TripState.empty());
              return;
            }

            _emitAndPublish(TripState.loaded(active: trips.first, all: trips));
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
