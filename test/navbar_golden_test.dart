// Golden tests for the floating glass `Navbar` (`lib/core/navbar.dart`).
//
// Refresh with: flutter test --update-goldens test/navbar_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';

import 'helpers/golden_test_helpers.dart';

Widget _navbarHarness({required int selectedIndex}) {
  return BlocProvider(
    create: (_) => NavbarCubit()..setNavIndex(selectedIndex),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: getTheme(),
      home: Scaffold(
        extendBody: true,
        body: const AmbientBackground(
          child: Center(child: Text('Content behind glass nav')),
        ),
        bottomNavigationBar: const Navbar(),
      ),
    ),
  );
}

void main() {
  testWidgets('Navbar renders Home tab selected', (tester) async {
    setGoldenViewSize(tester, const Size(390, 220));

    await tester.pumpWidget(_navbarHarness(selectedIndex: 0));
    await expectGolden(tester, find.byType(Navbar), 'goldens/navbar_home_selected.png');
  });

  testWidgets('Navbar renders Map tab selected', (tester) async {
    setGoldenViewSize(tester, const Size(390, 220));

    await tester.pumpWidget(_navbarHarness(selectedIndex: 1));
    await expectGolden(tester, find.byType(Navbar), 'goldens/navbar_map_selected.png');
  });
}
