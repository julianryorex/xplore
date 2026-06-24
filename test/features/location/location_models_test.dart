// Serialization tests for `LocationModel`.
//
// `LocationCubit.updateMyLocation` writes `myLocation.toJson()` straight to
// Realtime Database and reads peers back via `fromJson`, so the JSON shape (the
// snake_case `last_updated` key + ISO-8601 dates from `DateTimeConverter`) is a
// wire contract. The itinerary smoke test only covers the read path of a
// different model; this guards both directions of the converter.

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/location/models/location_models.dart';

void main() {
  test('round-trips through JSON preserving fields and the last_updated key', () {
    final model = LocationModel(
      id: 'user-1',
      lat: 35.6595,
      lng: 139.7005,
      lastUpdated: DateTime.utc(2023, 6, 15, 8, 30),
    );

    final json = model.toJson();

    // The DB schema uses snake_case; the Dart field is camelCase.
    expect(json['last_updated'], '2023-06-15T08:30:00.000Z');
    expect(json.containsKey('lastUpdated'), isFalse);

    expect(LocationModel.fromJson(json), model);
  });

  test('parses ISO-8601 timestamps back into DateTime', () {
    final model = LocationModel.fromJson({
      'id': 'user-2',
      'lat': 1.5,
      'lng': 2.5,
      'last_updated': '2024-01-02T03:04:05.000Z',
    });

    expect(model.lastUpdated, DateTime.utc(2024, 1, 2, 3, 4, 5));
  });
}
