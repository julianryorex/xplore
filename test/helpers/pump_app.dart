import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';

/// Shared widget-test harness, the xplore analogue of the reference repo's
/// `base_widget_mock`. Wraps [child] in a themed [MaterialApp] (the real
/// `getTheme()`) so widgets render against production colours/typography
/// without booting Firebase.
///
/// Pass [providers] to inject already-built cubits via `BlocProvider.value`;
/// the harness deliberately does **not** construct feature cubits itself so
/// each test stays explicit about what it wires up.
Widget wrapApp(
  Widget child, {
  List<BlocProvider> providers = const [],
  ThemeData? theme,
  Color? backgroundColor,
}) {
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? getTheme(),
    home: Scaffold(
      backgroundColor: backgroundColor ?? XploreColors.primaryBg,
      body: child,
    ),
  );

  if (providers.isEmpty) return app;
  return MultiBlocProvider(providers: providers, child: app);
}

/// Pumps [child] inside [wrapApp] at a fixed [size] / pixel ratio so golden
/// baselines are deterministic across runs. Resets the view on tear-down.
///
/// Goldens are an **Apple-only** artifact: text rasterisation differs on Linux,
/// so refresh baselines with `make test-gold` on a macOS host.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 240),
  List<BlocProvider> providers = const [],
  Color? backgroundColor,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapApp(child, providers: providers, backgroundColor: backgroundColor),
  );
  await tester.pumpAndSettle();
}
