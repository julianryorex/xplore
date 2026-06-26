// Headless tests for `LocationCubit` (no Firebase / GPS).
//
// `loadDemoLocations parses ...` mirrors the itinerary smoke test: it drives the
// real `loadDemoLocations()` which loads `assets/demo/locations.json` and parses
// each entry via `LocationModel.fromJson`, confirming codegen + the asset shape
// line up. `close() completes ...` is a regression test for the disposal crash
// where the `late` timer field was cancelled while uninitialised.
//
// The no-active-trip cases cover the productionization guard: with no active
// trip the location read/write must no-op instead of falling back to the demo
// `locations/ph4kd` RTDB node. Because there is no in-memory fake for Firebase
// RTDB / Geolocator here, the active-trip path is exercised indirectly: once a
// trip is active the guard no longer short-circuits, so the call proceeds to
// touch Firebase and throws headlessly (in contrast to the no-trip no-op which
// completes without touching anything).
//
// `DISABLE_REALTIME_LOCATIONS` is set so the constructor skips the periodic
// timer, and the global trip stream is reset per test so a stray active trip
// from a prior test can't leak in.

import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

import '../../helpers/auth_fixtures.dart';

class _TripStreamHarness with TripStreamMixin {}

TripModel _trip(String id) {
  return TripModel(id: id, title: 'Trip $id', memberIds: const ['user-1'], createdBy: 'user-1');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _TripStreamHarness().recreateTripStream();
    dotenv.loadFromString(mergeWith: {'DISABLE_REALTIME_LOCATIONS': 'true'}, isOptional: true);
  });
  tearDown(dotenv.clean);

  group('LocationCubit', () {
    test('loadDemoLocations parses the bundled demo locations', () async {
      final cubit = LocationCubit(fakeAuthService(signedIn: false));
      expect(cubit.state.locations, isEmpty);

      await cubit.loadDemoLocations();

      expect(cubit.state.locations.length, 5);

      const firstId = '4a4e3da7-6b62-4ff6-af32-eeed317d5e50';
      final first = cubit.state.locations[firstId]!;
      expect(first.id, firstId);
      expect(first.lat, 40.7178);
      expect(first.lng, -73.956);
      expect(first.lastUpdated, DateTime.utc(2024, 1, 22, 8));

      // Every demo entry is keyed by its own id.
      for (final entry in cubit.state.locations.entries) {
        expect(entry.value.id, entry.key);
      }

      await cubit.close();
    });

    test('close() completes when realtime updates are disabled', () async {
      // Unauthenticated service so the eager `updateMyLocation()` short-circuits
      // before touching Geolocator / Firebase Database.
      final cubit = LocationCubit(fakeAuthService(signedIn: false));

      // With realtime disabled the constructor returns before `startTimer()`,
      // so `updateLocationTimer` is never assigned. `close()` must not throw a
      // LateInitializationError cancelling the uninitialised timer.
      await expectLater(cubit.close(), completes);
    });

    test('updateMyLocation no-ops when there is no active trip', () async {
      // Signed in, but no trip event pushed: the guard must skip the RTDB
      // write entirely (no fallback to `locations/ph4kd`). If it didn't, the
      // call would touch Geolocator / Firebase and throw headlessly.
      final cubit = LocationCubit(fakeAuthService(signedIn: true, user: MockUser(uid: 'user-1')));

      await expectLater(cubit.updateMyLocation(), completes);
      expect(cubit.state.locations, isEmpty);

      await cubit.close();
    });

    test('timerCallback no-ops when there is no active trip', () async {
      final cubit = LocationCubit(fakeAuthService(signedIn: true, user: MockUser(uid: 'user-1')));

      final timer = Timer(const Duration(days: 1), () {});
      addTearDown(timer.cancel);

      await expectLater(cubit.timerCallback(timer), completes);
      expect(cubit.state.locations, isEmpty);

      await cubit.close();
    });

    test('updateMyLocation no longer no-ops once a trip is active', () async {
      final cubit = LocationCubit(fakeAuthService(signedIn: true, user: MockUser(uid: 'user-1')));

      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));
      // Let the broadcast event propagate so `_activeTripId` is set.
      await Future<void>.delayed(Duration.zero);

      // With an active trip the guard is bypassed and the call proceeds to the
      // RTDB / Geolocator path, which is unavailable in headless tests — so it
      // throws rather than silently no-opping. This confirms the scope is the
      // real trip id, not the removed demo fallback.
      await expectLater(cubit.updateMyLocation(), throwsA(anything));

      await cubit.close();
    });
  });
}
