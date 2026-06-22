// Golden test for `lib/core/header.dart`.
//
// Refresh with: flutter test --update-goldens test/header_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';

import 'helpers/golden_test_helpers.dart';

void main() {
  testWidgets('Header lays out leading, title, and trailing at compact height', (tester) async {
    setGoldenViewSize(tester, const Size(390, Header.padding + paddingUnit));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: ColoredBox(
          color: XploreColors.primaryBg,
          child: Header(
            leadingWidget: GlassIconButton(
              size: 44,
              iconSize: 22,
              icon: Icons.person_2_outlined,
              onTap: () {},
            ),
            titleWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back', style: TextStyle(color: XploreColors.subtleText, fontSize: 12)),
                Text('Julian', style: TextStyle(color: XploreColors.white, fontSize: 16)),
              ],
            ),
            trailingWidget: GlassIconButton(
              size: 44,
              iconSize: 22,
              icon: Icons.notifications_none_rounded,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await expectGolden(tester, find.byType(Header), 'goldens/header_compact.png');
  });
}
