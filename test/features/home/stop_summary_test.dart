import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/home/widgets/itinerary_preview.dart';

void main() {
  group('stopSummary', () {
    test('reads "so far" for a single stop', () {
      expect(stopSummary(['Tsukiji']), '1 stop so far');
    });

    test('names at most the first three stops', () {
      expect(
        stopSummary(['Tsukiji', 'Senso-ji', 'SkyTree', 'Ueno', 'Akihabara']),
        '5 stops · Tsukiji, Senso-ji, SkyTree',
      );
    });

    test('skips blank names and falls back to the count when none are left', () {
      expect(stopSummary(['', 'Ueno', '  ']), '3 stops · Ueno');
      expect(stopSummary(['', ' ']), '2 stops');
    });
  });
}
