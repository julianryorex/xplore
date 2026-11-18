import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:xplore/features/map/models/map_theme.dart';

/// Remembers the map colour scheme on this device. It is a device preference,
/// not user data, so it lives in its own box and survives sign-out.
class MapThemeStore {
  MapThemeStore({HiveInterface? hiveInterface}) : _hive = hiveInterface ?? Hive;

  final HiveInterface _hive;

  static const boxName = 'map_settings';
  static const _themeKey = 'theme';

  /// The saved theme, or [MapTheme.fallback] when none (or an unknown one) is stored.
  Future<MapTheme> load() async {
    final box = await _hive.openBox(boxName);
    final saved = box.get(_themeKey);
    return MapTheme.values.firstWhere((theme) => theme.name == saved, orElse: () => MapTheme.fallback);
  }

  /// Saves [theme] as the device's map colour scheme.
  Future<void> save(MapTheme theme) async {
    final box = await _hive.openBox(boxName);
    await box.put(_themeKey, theme.name);
  }
}
