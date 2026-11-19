import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';

StreamController<TripState> _tripStateStreamController = StreamController<TripState>.broadcast();

// The stream is a broadcast and keeps no history, so the most recent state is
// remembered here for listeners that subscribe after it was pushed.
TripState? _latestTripState;

mixin TripStreamMixin {
  /// Calls [callback] for every trip state pushed from now on.
  ///
  /// With [replayLatest], a listener created after the trip was already loaded
  /// (e.g. a lazily built cubit) is also told the current state right away, in
  /// a microtask, instead of waiting for the next change that may never come.
  StreamSubscription<TripState> listenToTripState(
    void Function(TripState state) callback, {
    bool replayLatest = false,
  }) {
    final subscription = _tripStateStreamController.stream.listen(callback);
    final latest = _latestTripState;
    if (replayLatest && latest != null) scheduleMicrotask(() => callback(latest));
    return subscription;
  }

  void pushTripEvent(TripState event) {
    _latestTripState = event;
    if (!_tripStateStreamController.isClosed) {
      _tripStateStreamController.add(event);
    }
  }

  @visibleForTesting
  void recreateTripStream() {
    _tripStateStreamController = StreamController<TripState>.broadcast();
    _latestTripState = null;
  }
}
