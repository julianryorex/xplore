import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/location/utils/last_seen.dart';

void main() {
  // Fixed reference clock so cases are deterministic.
  final now = DateTime(2026, 6, 23, 12, 0, 0);

  group('formatLastSeen', () {
    test('renders "Just now" for updates under a minute old', () {
      expect(formatLastSeen(now, now: now), 'Just now');
      expect(formatLastSeen(now.subtract(const Duration(seconds: 59)), now: now), 'Just now');
    });

    test('renders "Just now" for future timestamps (clock skew)', () {
      expect(formatLastSeen(now.add(const Duration(minutes: 5)), now: now), 'Just now');
    });

    test('renders minutes', () {
      expect(formatLastSeen(now.subtract(const Duration(minutes: 1)), now: now), '1 min ago');
      expect(formatLastSeen(now.subtract(const Duration(minutes: 4)), now: now), '4 min ago');
      expect(formatLastSeen(now.subtract(const Duration(minutes: 59)), now: now), '59 min ago');
    });

    test('renders hours', () {
      expect(formatLastSeen(now.subtract(const Duration(hours: 1)), now: now), '1 hr ago');
      expect(formatLastSeen(now.subtract(const Duration(hours: 23)), now: now), '23 hr ago');
    });

    test('renders days with pluralization', () {
      expect(formatLastSeen(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
      expect(formatLastSeen(now.subtract(const Duration(days: 6)), now: now), '6 days ago');
    });

    test('renders weeks with pluralization', () {
      expect(formatLastSeen(now.subtract(const Duration(days: 7)), now: now), '1 week ago');
      expect(formatLastSeen(now.subtract(const Duration(days: 21)), now: now), '3 weeks ago');
    });
  });

  group('isLocationStale', () {
    test('fresh updates are not stale', () {
      expect(isLocationStale(now.subtract(const Duration(minutes: 5)), now: now), isFalse);
      expect(isLocationStale(now, now: now), isFalse);
    });

    test('updates older than the threshold are stale', () {
      expect(isLocationStale(now.subtract(const Duration(minutes: 11)), now: now), isTrue);
    });

    test('boundary at exactly the threshold is not stale', () {
      expect(isLocationStale(now.subtract(kLocationStaleThreshold), now: now), isFalse);
    });

    test('honors a custom threshold', () {
      expect(
        isLocationStale(now.subtract(const Duration(minutes: 2)), now: now, threshold: const Duration(minutes: 1)),
        isTrue,
      );
    });
  });
}
