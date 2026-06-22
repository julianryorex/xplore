// Smoke test that exercises the app's core itinerary feature end-to-end on a
// Linux/CI host (no Firebase, GPS or GUI required).
//
// It drives the real `ItineraryCubit.loadDemoItinerary()` path, which:
//   * loads `assets/demo/itinerary.json` through the asset bundle, and
//   * deserializes it via the generated Freezed / json_serializable code.
//
// This verifies that codegen ran and the data layer works in this environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ItineraryCubit loads and parses the demo Tokyo itinerary', () async {
    final cubit = ItineraryCubit();
    expect(cubit.state, isA<InitialItineraryState>());

    await cubit.loadDemoItinerary();

    expect(cubit.state, isA<LoadedItineraryState>());
    final itinerary = (cubit.state as LoadedItineraryState).itinerary;

    expect(itinerary.id, 'ph4kd');
    expect(itinerary.invitees.length, 5);
    expect(itinerary.lastUpdated, DateTime.utc(2023, 6, 15, 8, 30));
    expect(itinerary.dailyPlans.length, 2);

    final firstDay = itinerary.dailyPlans.first;
    expect(firstDay.title, 'SkyTree Day');
    expect(firstDay.location, 'Tokyo');

    final firstStop = firstDay.plan.locations.first;
    expect(firstStop.name, 'Tsukiji Fish Market');
    expect(firstStop.completed, isTrue);

    await cubit.close();
  });
}
