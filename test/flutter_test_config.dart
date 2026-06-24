// Global test harness applied to every test under `test/`.
//
// Flutter's test runner automatically wraps each test entrypoint with the
// nearest `flutter_test_config.dart`, so this centralizes boilerplate that
// would otherwise be repeated in every (golden) test:
//   - Loads the Poppins font once so text renders with the real typeface
//     instead of the fallback "notdef" boxes in golden tests.
//   - Resets any per-test view overrides (physical size / device pixel ratio)
//     after each test, so a test that resizes the surface can't leak that
//     state into the next one.
//
// A test only needs to opt out (e.g. reset mid-test before another assertion)
// in the rare case it asserts against the default view after overriding it.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadPoppins();

  // Runs after every test in the tree; reverts physicalSize / devicePixelRatio
  // (and any other view overrides) back to their defaults.
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView?.reset();
  });

  await testMain();
}

Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  await loader.load();
}
