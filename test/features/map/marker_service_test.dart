// Read/delete tests for `MarkerService`'s hive_ce-backed marker icon cache.
//
// The service caches rendered avatar markers as raw `Uint8List` blobs keyed by
// marker id. These tests guard the Hive -> hive_ce migration for that byte-box
// path. We seed the box directly rather than via `updateMarkerIcon` because that
// writer also fires an un-awaited Firebase Storage upload (path_provider +
// FirebaseStorage), which isn't available headlessly; the hive_ce behaviour the
// migration touches is the box read/delete, which is what we assert here.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/map/services/marker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MarkerService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xplore_marker_service_test');
    Hive.init(tempDir.path);
    service = MarkerService();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> seedIcon(String id, Uint8List bytes) async {
    final box = await Hive.openBox(MarkerService.markerHiveBox);
    await box.put(id, bytes);
  }

  test('fetchMarkerIcon returns the cached bytes unchanged', () async {
    final bytes = Uint8List.fromList(List<int>.generate(128, (i) => i));
    await seedIcon('marker-1', bytes);

    expect(await service.fetchMarkerIcon('marker-1'), bytes);
  });

  test('fetchMarkerIcon returns null for an unknown marker', () async {
    expect(await service.fetchMarkerIcon('missing'), isNull);
  });

  test('deleteAll empties the marker box', () async {
    await seedIcon('marker-1', Uint8List.fromList([1, 2, 3]));

    await service.deleteAll();

    expect(await service.fetchMarkerIcon('marker-1'), isNull);
  });
}
