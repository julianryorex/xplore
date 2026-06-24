// Goldens for `SectionHeader` — the title row reused across every screen.
//
// APPLE-ONLY: refresh with `make test-gold` on macOS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/core/section_header.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('SectionHeader with a trailing action', (tester) async {
    await pumpForGolden(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: SectionHeader(title: 'Gallery', actionLabel: 'See all'),
      ),
      size: const Size(390, 120),
    );

    await expectLater(
      find.byType(SectionHeader),
      matchesGoldenFile('goldens/section_header_with_action.png'),
    );
  });

  testWidgets('SectionHeader title only', (tester) async {
    await pumpForGolden(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: SectionHeader(title: 'Today in Tokyo'),
      ),
      size: const Size(390, 120),
    );

    await expectLater(
      find.byType(SectionHeader),
      matchesGoldenFile('goldens/section_header_title_only.png'),
    );
  });
}
