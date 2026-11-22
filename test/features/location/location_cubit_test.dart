// Headless tests for `LocationCubit` (no Firebase / GPS).
//
// `loadDemoLocations parses ...` mirrors the itinerary smoke test: it drives the
// real `loadDemoLocations()` which loads `assets/demo/locations.json` and parses
// each entry via `LocationModel.fromJson`, confirming codegen + the asset shape
// line up. `close() completes ...` is a regression test for the disposal crash
// where realtime cleanup assumed a timer had been started.
//
// The no-active-trip cases cover the productionization guard: with no active
// trip the location read/write must no-op instead of falling back to the demo
// `locations/ph4kd` RTDB node. Because there is no in-memory fake for Firebase
// RTDB / Geolocator here, the active-trip path is exercised indirectly: once a
// trip is active the guard no longer short-circuits, so the call proceeds to
// touch Firebase and throws headlessly (in contrast to the no-trip no-op which
// completes without touching anything). The same probe shows the trip window
// gate: an upcoming trip no-ops, a trip under way reaches Firebase. The
// share / clear / off decision itself is covered by `locationSharingFor`.
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
import 'package:xplore/features/trip/models/trip_window.dart';

import '../../helpers/auth_fixtures.dart';

class _TripStreamHarness with TripStreamMixin {}

TripModel _trip(String id, {DateTime? startDate, DateTime? endDate}) {
  return TripModel(
    id: id,
    title: 'Trip $id',
    memberIds: const ['user-1'],
    createdBy: 'user-1',
    startDate: startDate,
    endDate: endDate,
  );
}

// A trip running June 3 to 9, inclusive.
final _june3 = DateTime(2026, 6, 3);
final _june9 = DateTime(2026, 6, 9);

LocationSharing _sharingOn(DateTime now, {DateTime? start, DateTime? end}) {
  return locationSharingFor(tripWindowOn(now, start: start, end: end));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _TripStreamHarness().recreateTripStream();
    dotenv.loadFromString(mergeWith: {'DISABLE_REALTIME_LOCATIONS': 'true'}, isOptional: true);
  });
  tearDown(dotenv.clean);

  group('locationSharingFor', () {
    test('is off for a trip without dates', () {
      expect(_sharingOn(DateTime(2026, 6, 5)), LocationSharing.off);
      expect(_sharingOn(DateTime(2026, 6, 5), start: _june3), LocationSharing.off);
    });

    test('is off the day before an upcoming trip starts', () {
      expect(_sharingOn(DateTime(2026, 6, 2, 23, 59), start: _june3, end: _june9), LocationSharing.off);
    });

    test('shares from the start of the first day to the end of the last day', () {
      expect(_sharingOn(DateTime(2026, 6, 3), start: _june3, end: _june9), LocationSharing.share);
      expect(_sharingOn(DateTime(2026, 6, 6, 12), start: _june3, end: _june9), LocationSharing.share);
      expect(_sharingOn(DateTime(2026, 6, 9, 23, 59), start: _june3, end: _june9), LocationSharing.share);
    });

    test('clears the day after the trip ends', () {
      expect(_sharingOn(DateTime(2026, 6, 10), start: _june3, end: _june9), LocationSharing.clear);
    });
  });

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
      // so `_updateLocationTimer` stays null. `close()` must treat that as a
      // valid no-op.
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

    Future<LocationCubit> cubitWithActiveTrip(TripModel trip, {required DateTime now}) async {
      final cubit = LocationCubit(
        fakeAuthService(signedIn: true, user: MockUser(uid: 'user-1')),
        clock: () => now,
      );
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: trip, all: [trip]));
      // Let the broadcast event propagate so the active trip is set.
      await Future<void>.delayed(Duration.zero);
      return cubit;
    }

    test('updateMyLocation reaches Firebase while the active trip is under way', () async {
      final trip = _trip('trip-1', startDate: _june3, endDate: _june9);
      final cubit = await cubitWithActiveTrip(trip, now: DateTime(2026, 6, 5));

      // The guards are passed and the call proceeds to the RTDB / Geolocator
      // path, which is unavailable in headless tests, so it throws rather than
      // silently no-opping.
      await expectLater(cubit.updateMyLocation(), throwsA(anything));

      await cubit.close();
    });

    test('updateMyLocation and timerCallback stay off for an upcoming trip', () async {
      final trip = _trip('trip-1', startDate: _june3, endDate: _june9);
      final cubit = await cubitWithActiveTrip(trip, now: DateTime(2026, 6, 1));

      final timer = Timer(const Duration(days: 1), () {});
      addTearDown(timer.cancel);

      // Completing (instead of throwing on Firebase) proves nothing was read or written.
      await expectLater(cubit.updateMyLocation(), completes);
      await expectLater(cubit.timerCallback(timer), completes);
      expect(cubit.state.locations, isEmpty);

      await cubit.close();
    });

    test('updateMyLocation stays off for an undated trip', () async {
      final cubit = await cubitWithActiveTrip(_trip('trip-1'), now: DateTime(2026, 6, 5));

      await expectLater(cubit.updateMyLocation(), completes);

      await cubit.close();
    });
  });
}
