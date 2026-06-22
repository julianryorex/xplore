import 'dart:typed_data';
import 'dart:ui' show loadFontFromList;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Loads Poppins and Material Icons so golden tests render real glyphs.
Future<void> loadGoldenTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_fontsLoaded) return;

  final poppins = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  await poppins.load();

  final iconBytes = await rootBundle.load('test/fixtures/MaterialIcons-Regular.otf');
  await loadFontFromList(iconBytes.buffer.asUint8List(), fontFamily: 'MaterialIcons');
  _fontsLoaded = true;
}

/// Pumps a few frames without [pumpAndSettle], which can hang on BackdropFilter.
Future<void> pumpForSnapshot(WidgetTester tester, {int frameCount = 5}) async {
  await tester.pump();
  for (var i = 0; i < frameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Captures a golden after pumping frames for layout/blur to settle.
Future<void> expectGolden(
  WidgetTester tester,
  Finder finder,
  Object golden, {
  int frameCount = 5,
}) async {
  await pumpForSnapshot(tester, frameCount: frameCount);
  await expectLater(finder, matchesGoldenFile(golden));
}

void setGoldenViewSize(
  WidgetTester tester,
  Size size, {
  double devicePixelRatio = 1.0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wraps a widget with notch-style safe-area insets for home-screen goldens.
Widget withNotchInsets(
  Widget child, {
  double top = 47,
  double bottom = 34,
}) {
  return MediaQuery(
    data: MediaQueryData(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      viewPadding: EdgeInsets.only(top: top, bottom: bottom),
    ),
    child: child,
  );
}
