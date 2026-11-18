import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/map/models/map_theme.dart';
import 'package:xplore/features/map/services/map_theme_store.dart';

void main() {
  late Directory tempDir;
  late MapThemeStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_map_theme_store_test');
    Hive.init(tempDir.path);
    store = MapThemeStore();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('falls back to the default theme when nothing is saved', () async {
    expect(await store.load(), MapTheme.fallback);
  });

  test('returns the saved theme', () async {
    await store.save(MapTheme.daylight);

    expect(await store.load(), MapTheme.daylight);
  });

  test('falls back when the saved name is no longer a theme', () async {
    final box = await Hive.openBox(MapThemeStore.boxName);
    await box.put('theme', 'neon');

    expect(await store.load(), MapTheme.fallback);
  });
}
