// Golden tests for liquid-glass primitives in `lib/core/glass.dart`.
//
// Refresh with: flutter test --update-goldens test/glass_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';

import 'helpers/golden_test_helpers.dart';

void main() {
  testWidgets('GlassSurface and GlassIconButton render over ambient content', (tester) async {
    setGoldenViewSize(tester, const Size(320, 320));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: AmbientBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassSurface(
                  padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 2, vertical: paddingUnit),
                  child: Text('Liquid glass', style: TextStyle(color: XploreColors.white)),
                ),
                const SizedBox(height: paddingUnit * 2),
                GlassIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectGolden(
      tester,
      find.byType(AmbientBackground),
      'goldens/glass_surface_and_icon_button.png',
    );
  });
}
