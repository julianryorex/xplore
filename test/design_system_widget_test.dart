// Widget and behaviour tests for the liquid-glass design system.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/core/section_header.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/screens/home_page.dart';

import 'helpers/golden_test_helpers.dart';

/// Minimal valid PNG (1×1) for avatar golden/behaviour checks.
final _testAvatarPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Finder _headerGreeting(String name) {
  return find.descendant(of: find.byType(Header), matching: find.text(name));
}

Future<void> _unloadWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<ItineraryCubit> _loadedItineraryCubit() async {
  final cubit = ItineraryCubit();
  await cubit.loadDemoItinerary();
  return cubit;
}

Widget _homeHarness({
  required ItineraryCubit itineraryCubit,
  required ProfileCubit profileCubit,
  required NavbarCubit navbarCubit,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<NavbarCubit>.value(value: navbarCubit),
      BlocProvider<ItineraryCubit>.value(value: itineraryCubit),
      BlocProvider<ProfileCubit>.value(value: profileCubit),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: getTheme(),
      home: const HomePage(),
    ),
  );
}

void main() {
  group('Header profile integration', () {
    testWidgets('greeting and avatar react to ProfileCubit state', (tester) async {
      final itineraryCubit = await _loadedItineraryCubit();
      addTearDown(itineraryCubit.close);

      final profileCubit = ProfileCubit.forTest();
      addTearDown(profileCubit.close);

      await tester.pumpWidget(
        _homeHarness(
          itineraryCubit: itineraryCubit,
          profileCubit: profileCubit,
          navbarCubit: NavbarCubit(),
        ),
      );
      await pumpForSnapshot(tester);

      expect(_headerGreeting('Julian'), findsOneWidget);
      expect(find.byIcon(Icons.person_2_outlined), findsOneWidget);

      profileCubit.emit(profileCubit.state.copyWith(name: 'Ada Lovelace'));
      await pumpForSnapshot(tester);

      expect(_headerGreeting('Ada'), findsOneWidget);
      expect(_headerGreeting('Julian'), findsNothing);

      profileCubit.emit(
        ProfileState(id: userId, name: 'Ada Lovelace', profilePicture: _testAvatarPng),
      );
      await pumpForSnapshot(tester);

      expect(find.byIcon(Icons.person_2_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byType(Header),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).image != null,
          ),
        ),
        findsOneWidget,
      );

      await _unloadWidgetTree(tester);
    });
  });

  group('Navbar', () {
    testWidgets('tab tap updates NavbarCubit and navigates', (tester) async {
      final navCubit = NavbarCubit();

      await tester.pumpWidget(
        MaterialApp(
          theme: getTheme(),
          initialRoute: Paths.home,
          onGenerateRoute: (settings) {
            final label = settings.name == Paths.map ? 'Map screen' : 'Home screen';
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => BlocProvider<NavbarCubit>.value(
                value: navCubit,
                child: Scaffold(
                  body: Center(child: Text(label)),
                  bottomNavigationBar: const Navbar(),
                ),
              ),
            );
          },
        ),
      );
      await pumpForSnapshot(tester);

      expect(navCubit.state, 0);
      expect(find.text('Home screen'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await pumpForSnapshot(tester);

      expect(navCubit.state, 1);
      expect(find.text('Map screen'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('action button fires onAction', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: getTheme(),
          home: Scaffold(
            body: SectionHeader(
              title: 'Daily Plans',
              actionLabel: 'See all',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      await pumpForSnapshot(tester);

      await tester.tap(find.text('See all'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
