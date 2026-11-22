/// Where [now] falls relative to a trip's dates.
enum TripWindow {
  /// The trip has no complete date range yet, so it is not finalized.
  undated,
  upcoming,
  underWay,
  ended,
}

/// Places [now] against a trip running from [start] to [end], both inclusive
/// and compared by calendar day. A trip missing either date is
/// [TripWindow.undated].
TripWindow tripWindowOn(DateTime now, {required DateTime? start, required DateTime? end}) {
  if (start == null || end == null) {
    return TripWindow.undated;
  }
  final today = _dateOnly(now);
  if (today.isBefore(_dateOnly(start))) {
    return TripWindow.upcoming;
  }
  return today.isAfter(_dateOnly(end)) ? TripWindow.ended : TripWindow.underWay;
}

/// Whole days from [now] until [start], by calendar day; 0 on the day itself
/// and negative once it has passed.
int daysUntil(DateTime start, {required DateTime now}) {
  // Built in UTC so a daylight-saving change between the two days cannot make
  // the difference land an hour short of a whole day.
  final from = DateTime.utc(now.year, now.month, now.day);
  final to = DateTime.utc(start.year, start.month, start.day);
  return to.difference(from).inDays;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
