// Renders the real `ItineraryCard` widgets (with the app theme + demo data) to a
// PNG golden. Used to capture a visual artifact proving the Flutter UI renders
// in this environment, since the full app GUI targets iOS/macOS only.
//
// Generate / refresh with:  flutter test --update-goldens test/itinerary_card_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';

Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  await loader.load();
}

void main() {
  testWidgets('ItineraryCard carousel renders with demo data', (tester) async {
    await _loadPoppins();

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

    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/itinerary_cards.png'));

    await cubit.close();
  });
}
