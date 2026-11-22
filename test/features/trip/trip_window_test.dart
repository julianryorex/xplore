import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/models/trip_window.dart';

void main() {
  final start = DateTime(2027, 6, 3);
  final end = DateTime(2027, 6, 9);

  TripWindow windowOn(DateTime now) => tripWindowOn(now, start: start, end: end);

  test('a trip is under way from the start of its first day to the end of its last', () {
    expect(windowOn(DateTime(2027, 6, 2, 23, 59)), TripWindow.upcoming);
    expect(windowOn(DateTime(2027, 6, 3)), TripWindow.underWay);
    expect(windowOn(DateTime(2027, 6, 9, 23, 59)), TripWindow.underWay);
    expect(windowOn(DateTime(2027, 6, 10)), TripWindow.ended);
  });

  test('a trip missing either date is undated', () {
    expect(tripWindowOn(DateTime(2027, 6, 5), start: start, end: null), TripWindow.undated);
    expect(tripWindowOn(DateTime(2027, 6, 5), start: null, end: end), TripWindow.undated);
  });

  test('daysUntil counts calendar days, ignoring the time of day', () {
    expect(daysUntil(start, now: DateTime(2026, 11, 20, 18)), 195);
    expect(daysUntil(start, now: DateTime(2027, 6, 2, 23, 59)), 1);
    expect(daysUntil(start, now: DateTime(2027, 6, 3, 9)), 0);
  });
}
