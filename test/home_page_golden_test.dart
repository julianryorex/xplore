// Golden test for the Home screen glass composition (`lib/screens/home_page.dart`).
//
// Refresh with: flutter test --update-goldens test/home_page_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/screens/home_page.dart';

import 'helpers/golden_test_helpers.dart';

void main() {
  testWidgets('HomePage pins glass header and footer over scrolled demo content', (tester) async {
    setGoldenViewSize(tester, const Size(390, 780));

    final itineraryCubit = ItineraryCubit();
    addTearDown(itineraryCubit.close);
    await itineraryCubit.loadDemoItinerary();

    final profileCubit = ProfileCubit.forTest();
    addTearDown(profileCubit.close);

    await tester.pumpWidget(
      withNotchInsets(
        MultiBlocProvider(
          providers: [
            BlocProvider<NavbarCubit>(create: (_) => NavbarCubit()),
            BlocProvider<ItineraryCubit>.value(value: itineraryCubit),
            BlocProvider<ProfileCubit>.value(value: profileCubit),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: getTheme(),
            home: const HomePage(),
          ),
        ),
      ),
    );
    await expectGolden(
      tester,
      find.byType(HomePage),
      'goldens/home_page_glass_composition.png',
    );
  });
}
