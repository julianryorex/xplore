// Golden test for `lib/core/ambient_background.dart`.
//
// Refresh with: flutter test --update-goldens test/ambient_background_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/core/ambient_background.dart';

import 'helpers/golden_test_helpers.dart';

void main() {
  testWidgets('AmbientBackground paints brand glows over base colour', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setGoldenViewSize(tester, const Size(390, 320));

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AmbientBackground(child: SizedBox.expand()),
      ),
    );
    await expectGolden(
      tester,
      find.byType(AmbientBackground),
      'goldens/ambient_background.png',
    );
  });
}
