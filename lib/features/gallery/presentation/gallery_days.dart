import 'package:flutter/foundation.dart';
import 'package:xplore/features/gallery/models/image_models.dart';

/// One calendar day of the shared album, as the gallery page lists it.
@immutable
class GalleryDay {
  const GalleryDay({required this.date, required this.photos, required this.firstIndex});

  /// Local midnight of the day the photos were taken.
  final DateTime date;

  /// The day's photos, newest first.
  final List<ImageModel> photos;

  /// Index of [photos]' first entry in the whole newest-first gallery, so a tap
  /// can open the viewer at the right position.
  final int firstIndex;
}

/// Splits [newestFirst] into calendar days (device-local time), keeping the
/// newest-first order both across and within days.
List<GalleryDay> groupGalleryDays(List<ImageModel> newestFirst) {
  final days = <GalleryDay>[];
  var start = 0;
  while (start < newestFirst.length) {
    final date = _localDay(newestFirst[start].createdAt);
    var end = start + 1;
    while (end < newestFirst.length && _localDay(newestFirst[end].createdAt) == date) {
      end++;
    }
    days.add(GalleryDay(date: date, photos: newestFirst.sublist(start, end), firstIndex: start));
    start = end;
  }
  return days;
}

/// The overline above a day's heading, e.g. "DAY 5 · TODAY", "DAY 4", "YESTERDAY".
///
/// Day numbers count from [tripStart] (Day 1) and are omitted for days before it
/// or when the trip has no start date. Returns null when there is nothing to say.
String? dayOverline(DateTime day, {required DateTime today, DateTime? tripStart}) {
  final parts = <String>[];
  if (tripStart != null) {
    final offset = _daysBetween(_localDay(tripStart), day);
    if (offset >= 0) parts.add('DAY ${offset + 1}');
  }
  final ago = _daysBetween(day, _localDay(today));
  if (ago == 0) parts.add('TODAY');
  if (ago == 1) parts.add('YESTERDAY');
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "1 photo" / "9 photos".
String photoCountLabel(int count) => '$count ${count == 1 ? 'photo' : 'photos'}';

/// A day's heading, e.g. "Tue 16 Sep".
String dayHeading(DateTime day) => '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';

/// The span of days the album covers, e.g. "16 Sep", "12–16 Sep" or "30 Aug – 2 Sep".
String albumDateRange(DateTime oldest, DateTime newest) {
  final from = _localDay(oldest);
  final to = _localDay(newest);
  String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  if (from == to) return dayMonth(to);
  if (from.year != to.year) return '${dayMonth(from)} ${from.year} – ${dayMonth(to)} ${to.year}';
  if (from.month != to.month) return '${dayMonth(from)} – ${dayMonth(to)}';
  return '${from.day}–${dayMonth(to)}';
}

/// One photo's cell in a day's 3-column mosaic, in cell units.
@immutable
class MosaicTile {
  const MosaicTile({required this.column, required this.row, this.columnSpan = 1, this.rowSpan = 1});

  final int column;
  final int row;
  final int columnSpan;
  final int rowSpan;

  /// Wide tiles have room to show who added the photo.
  bool get showsUploader => columnSpan >= 2;

  @override
  bool operator ==(Object other) =>
      other is MosaicTile &&
      other.column == column &&
      other.row == row &&
      other.columnSpan == columnSpan &&
      other.rowSpan == rowSpan;

  @override
  int get hashCode => Object.hash(column, row, columnSpan, rowSpan);

  @override
  String toString() => 'MosaicTile($column, $row, ${columnSpan}x$rowSpan)';
}

/// Columns in a day's mosaic.
const mosaicColumns = 3;

/// Lays out [count] photos in a 3-column mosaic; tile `i` is photo `i`, in reading order.
///
/// With three or more photos the day opens with a 2×2 lead beside two stacked
/// squares, the lead on the left when [leadOnLeft] (pass alternating values per
/// day so the rhythm varies). The rest fill rows of three; a final pair becomes a
/// 2-wide plus a 1-wide tile and a final single photo spans the full width.
List<MosaicTile> mosaicLayout(int count, {required bool leadOnLeft}) {
  if (count <= 0) return const [];
  if (count == 1) return const [MosaicTile(column: 0, row: 0, columnSpan: 3, rowSpan: 2)];
  if (count == 2) {
    return leadOnLeft
        ? const [MosaicTile(column: 0, row: 0, columnSpan: 2, rowSpan: 2), MosaicTile(column: 2, row: 0, rowSpan: 2)]
        : const [MosaicTile(column: 0, row: 0, rowSpan: 2), MosaicTile(column: 1, row: 0, columnSpan: 2, rowSpan: 2)];
  }

  final tiles = <MosaicTile>[
    if (leadOnLeft) ...const [
      MosaicTile(column: 0, row: 0, columnSpan: 2, rowSpan: 2),
      MosaicTile(column: 2, row: 0),
      MosaicTile(column: 2, row: 1),
    ] else ...const [
      MosaicTile(column: 0, row: 0),
      MosaicTile(column: 1, row: 0, columnSpan: 2, rowSpan: 2),
      MosaicTile(column: 0, row: 1),
    ],
  ];

  final rest = count - tiles.length;
  final fullRows = rest ~/ mosaicColumns;
  for (var r = 0; r < fullRows; r++) {
    for (var c = 0; c < mosaicColumns; c++) {
      tiles.add(MosaicTile(column: c, row: 2 + r));
    }
  }

  final lastRow = 2 + fullRows;
  switch (rest % mosaicColumns) {
    case 2:
      tiles
        ..add(MosaicTile(column: 0, row: lastRow, columnSpan: 2))
        ..add(MosaicTile(column: 2, row: lastRow));
    case 1:
      tiles.add(MosaicTile(column: 0, row: lastRow, columnSpan: 3));
  }
  return tiles;
}

/// Rows a mosaic of [tiles] occupies.
int mosaicRowCount(List<MosaicTile> tiles) =>
    tiles.fold(0, (rows, tile) => tile.row + tile.rowSpan > rows ? tile.row + tile.rowSpan : rows);

DateTime _localDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

// Counted on UTC dates so a daylight-saving change never yields a 23h "day".
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
