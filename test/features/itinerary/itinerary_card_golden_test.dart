// Renders the real `ItineraryCard` widgets (with the app theme + demo data) to a
// PNG golden. Used to capture a visual artifact proving the Flutter UI renders
// in the supported iOS CI environment.
//
// Run or refresh this test on the Codemagic Apple build host only; Linux text
// rasterization does not match the checked-in baseline.
//   flutter test --update-goldens test/features/itinerary/itinerary_card_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';

// Fonts are loaded once globally by `test/flutter_test_config.dart`.
void main() {
  testWidgets('ItineraryCard carousel renders with demo data', (tester) async {
    final cubit = ItineraryCubit();
    await cubit.loadDemoItinerary();
    final dailyPlans = (cubit.state as LoadedItineraryState).itinerary.dailyPlans;

    tester.view.physicalSize = const Size(540, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                for (final (index, plan) in dailyPlans.indexed)
                  Padding(
                    padding: const EdgeInsets.all(paddingUnit),
                    child: SizedBox(
                      width: ItineraryCard.width,
                      height: ItineraryCard.height,
                      child: ItineraryCard(dailyPlan: plan, dayIndex: index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/itinerary_cards.png'));

    await cubit.close();
  });
}
