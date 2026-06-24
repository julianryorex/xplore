import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/core/section_header.dart';

import 'helpers/pump_app.dart';

const _title = 'Unable to load trips';
const _message = 'Check your connection and try again.';

void main() {
  testWidgets('ErrorState renders with retry action', (tester) async {
    await pumpForGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(paddingUnit * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(title: 'Daily Plans', actionLabel: 'See all'),
            const SizedBox(height: paddingUnit * 1.5),
            ErrorState(title: _title, message: _message, onRetry: () {}),
          ],
        ),
      ),
      size: const Size(390, 200),
    );

    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/error_state.png'));
  });

  testWidgets('ErrorState renders without retry action', (tester) async {
    await pumpForGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(paddingUnit * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(title: 'Daily Plans', actionLabel: 'See all'),
            const SizedBox(height: paddingUnit * 1.5),
            const ErrorState(title: _title, message: _message),
          ],
        ),
      ),
      size: const Size(390, 200),
    );

    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/error_state_no_retry.png'));
  });
}
