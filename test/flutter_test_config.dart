import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Global test bootstrap (auto-discovered by `flutter test` for every test in
/// this tree).
///
/// Ported from the reference repo's `flutter_test_config.dart` +
/// `golden_toolkit.loadAppFonts()`. Its one job is to load **all** bundled
/// fonts once — the Poppins families *and* the `MaterialIcons` glyph font — so
/// that any widget/golden test renders real text and icons instead of the Ahem
/// fallback / tofu boxes. Without this, every golden would have to load fonts by
/// hand (the pattern the old `itinerary_card` / `profile_page` tests used) and
/// any test that forgot would silently bake placeholder glyphs into its
/// baseline.
///
/// Keep this lean: anything that mutates global state per-test (view size,
/// platform channels) belongs in the individual test or a helper so it can be
/// scoped and reset.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();
  return testMain();
}

/// Loads every font declared in the app's `FontManifest.json` (Poppins) as well
/// as the framework-provided `MaterialIcons` font, mirroring what
/// `golden_toolkit.loadAppFonts()` does.
Future<void> _loadAppFonts() async {
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );

  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = _normalizeFamily(entry['family'] as String);
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Package-scoped families arrive as `packages/<pkg>/<family>`; the renderer
/// resolves them by the trailing family name, so strip the prefix when loading.
String _normalizeFamily(String family) {
  if (!family.startsWith('packages/')) return family;
  return family.split('/').last;
}
