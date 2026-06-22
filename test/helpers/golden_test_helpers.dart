import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
