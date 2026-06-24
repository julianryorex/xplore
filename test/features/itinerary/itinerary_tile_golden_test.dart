// Golden for `ItineraryTile` — the row used in the itinerary plan list.
//
// APPLE-ONLY: refresh with `make test-gold` on macOS. Text rasterises
// differently on Linux and will not match this baseline.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_tile.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('ItineraryTile renders the location name and map action', (tester) async {
    const plan = LocationPlanModel(
      name: 'Tsukiji Outer Market',
      completed: false,
      placeId: 'place-123',
      description: 'Fresh sushi breakfast and street food stalls.',
    );

    await pumpForGolden(
      tester,
      const Center(child: ItineraryTile(locationPlan: plan, width: 320, height: 80)),
      size: const Size(360, 160),
    );

    await expectLater(find.byType(ItineraryTile), matchesGoldenFile('goldens/itinerary_tile.png'));
  });
}
