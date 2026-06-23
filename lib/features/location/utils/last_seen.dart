/// Helpers for presenting how recently a member's location was updated.
///
/// Kept free of Flutter/Firebase imports so the formatting and staleness logic
/// can be unit-tested headlessly.
library;

/// A location is considered "stale" once its last update is older than this.
///
/// Mirrors the fade threshold used for map markers so the textual "last seen"
/// state and the marker opacity stay in sync.
const Duration kLocationStaleThreshold = Duration(minutes: 10);

/// Whether [lastUpdated] is old enough to be treated as stale.
///
/// [now] defaults to [DateTime.now] and exists for deterministic testing.
bool isLocationStale(DateTime lastUpdated, {DateTime? now, Duration threshold = kLocationStaleThreshold}) {
  final reference = now ?? DateTime.now();
  return reference.difference(lastUpdated) > threshold;
}

/// Returns a short, human-friendly relative time such as `Just now`,
/// `4 min ago`, `2 hr ago`, `3 days ago`, or `2 weeks ago`.
///
/// Future timestamps (clock skew) and updates under a minute old both render
/// as `Just now`. [now] defaults to [DateTime.now] and exists for testing.
String formatLastSeen(DateTime lastUpdated, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(lastUpdated);

  if (diff.inSeconds < 60) return 'Just now';

  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return '$minutes min ago';
  }

  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return '$hours hr ago';
  }

  if (diff.inDays < 7) {
    final days = diff.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  final weeks = diff.inDays ~/ 7;
  return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
}
