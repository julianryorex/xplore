import 'dart:async';

import 'helpers/golden_test_helpers.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadGoldenTestFonts();
  await testMain();
}
