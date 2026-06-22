import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supported platforms for checked-in golden baselines.
const supportedGoldenPlatforms = {'linux', 'macos'};

/// Golden path for the current OS, e.g. `goldens/itinerary_cards.linux.png`.
String platformGoldenPath(String basename) {
  final platform = Platform.operatingSystem;
  if (!supportedGoldenPlatforms.contains(platform)) {
    fail(
      'No golden baseline for platform "$platform". '
      'Supported: ${supportedGoldenPlatforms.join(", ")}.',
    );
  }
  return 'goldens/$basename.$platform.png';
}

/// Loads Poppins so golden tests render the app typography instead of Ahem.
Future<void> loadGoldenTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final poppins = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));

  await poppins.load();
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
