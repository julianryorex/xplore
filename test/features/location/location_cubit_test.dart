// Headless test for `LocationCubit`'s demo-data path (no Firebase / GPS).
//
// Mirrors the itinerary smoke test for the location feature: it drives the real
// `loadDemoLocations()` which loads `assets/demo/locations.json` and parses each
// entry via `LocationModel.fromJson`, confirming codegen + the asset shape line
// up. `DISABLE_REALTIME_LOCATIONS` is set so the constructor skips the periodic
// timer, and an unauthenticated service makes the eager `updateMyLocation()`
// short-circuit before touching Geolocator or the database.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => dotenv.loadFromString(
      mergeWith: {'DISABLE_REALTIME_LOCATIONS': 'true'},
      isOptional: true,
    ),
  );
  tearDown(dotenv.clean);

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

    // NB: `close()` is intentionally not called. With realtime disabled the
    // constructor returns before `startTimer()`, leaving the `late
    // updateLocationTimer` uninitialised, so `close()` would throw a
    // LateInitializationError. No timer/subscription was started, so there is
    // nothing to dispose here.
  });
}
