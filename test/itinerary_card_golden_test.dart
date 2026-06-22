// Renders the real `ItineraryCard` widgets (with the app theme + demo data) to a
// PNG golden. Used to capture a visual artifact proving the Flutter UI renders
// in this environment, since the full app GUI targets iOS/macOS only.
//
// Goldens are platform-specific because text rasterization differs between Linux
// CI and macOS dev machines. Refresh on the target platform:
//   flutter test --update-goldens test/itinerary_card_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';

import 'helpers/golden_test_helpers.dart';

void main() {
  testWidgets('ItineraryCard carousel renders with demo data', (tester) async {
    await loadGoldenTestFonts();

    final cubit = ItineraryCubit();
    await cubit.loadDemoItinerary();
    final dailyPlans = (cubit.state as LoadedItineraryState).itinerary.dailyPlans;

    setGoldenViewSize(tester, const Size(540, 380));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: Scaffold(
          backgroundColor: XploreColors.primaryBg,
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final plan in dailyPlans)
                  Padding(
                    padding: const EdgeInsets.all(paddingUnit),
                    child: SizedBox(
                      width: ItineraryCard.width,
                      height: ItineraryCard.height,
                      child: ItineraryCard(dailyPlan: plan),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(platformGoldenPath('itinerary_cards')),
    );

    await cubit.close();
  });
}
