import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/screens/itinerary_focus_page.dart';

void main() {
  testWidgets('ItineraryFocusPage shows a helpful empty gallery state', (tester) async {
    const locationPlan = LocationPlanModel(
      name: 'Tsukiji Fish Market',
      completed: true,
      placeId: 'ChIJISz8h9hx5kcRR6Ko1HuQAg4',
      description: 'Fresh seafood stalls and classic Tokyo market energy.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: const ItineraryFocusPage(locationPlan: locationPlan),
      ),
    );

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('No photos here yet'), findsOneWidget);
    expect(find.text('Photos from this stop will appear here once your group adds them.'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });
}
