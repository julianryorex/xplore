import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';

StreamController<TripState> _tripStateStreamController = StreamController<TripState>.broadcast();

mixin TripStreamMixin {
  StreamSubscription<TripState> listenToTripState(void Function(TripState state) callback) {
    return _tripStateStreamController.stream.listen(callback);
  }

  void pushTripEvent(TripState event) {
    if (!_tripStateStreamController.isClosed) {
      _tripStateStreamController.add(event);
    }
  }

  @visibleForTesting
  void recreateTripStream() {
    _tripStateStreamController = StreamController<TripState>.broadcast();
  }
}
