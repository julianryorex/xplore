import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';

ImageModel _photo(String id, DateTime createdAt) =>
    ImageModel(id: id, createdAt: createdAt, lowResImage: Uint8List(0), isUploading: EUploadStatus.complete);

/// Every cell a tile covers, as "column,row".
Iterable<String> _cells(MosaicTile tile) sync* {
  for (var c = tile.column; c < tile.column + tile.columnSpan; c++) {
    for (var r = tile.row; r < tile.row + tile.rowSpan; r++) {
      yield '$c,$r';
    }
  }
}

void main() {
  group('groupGalleryDays', () {
    test('splits newest-first photos into local calendar days and tracks gallery offsets', () {
      final photos = [
        _photo('a', DateTime(2025, 9, 16, 23, 59)),
        _photo('b', DateTime(2025, 9, 16, 0, 0)),
        _photo('c', DateTime(2025, 9, 15, 18)),
        _photo('d', DateTime(2025, 9, 12, 9)),
        _photo('e', DateTime(2025, 9, 12, 8)),
      ];

      final days = groupGalleryDays(photos);

      expect(days.map((day) => day.date), [DateTime(2025, 9, 16), DateTime(2025, 9, 15), DateTime(2025, 9, 12)]);
      expect(days.map((day) => day.photos.map((p) => p.id).join()), ['ab', 'c', 'de']);
      expect(days.map((day) => day.firstIndex), [0, 2, 3]);
    });

    test('groups UTC timestamps by the device-local day', () {
      final utc = DateTime.utc(2025, 9, 16, 12);
      final days = groupGalleryDays([_photo('a', utc)]);
      final local = utc.toLocal();

      expect(days.single.date, DateTime(local.year, local.month, local.day));
    });

    test('returns no days for an empty album', () {
      expect(groupGalleryDays(const []), isEmpty);
    });
  });

  group('dayOverline', () {
    final today = DateTime(2025, 9, 16, 15, 30);
    final start = DateTime(2025, 9, 12);

    test('numbers days from the trip start and marks today and yesterday', () {
      expect(dayOverline(DateTime(2025, 9, 16), today: today, tripStart: start), 'DAY 5 · TODAY');
      expect(dayOverline(DateTime(2025, 9, 15), today: today, tripStart: start), 'DAY 4 · YESTERDAY');
      expect(dayOverline(DateTime(2025, 9, 12), today: today, tripStart: start), 'DAY 1');
    });

    test('omits the day number before the trip starts or without a start date', () {
      expect(dayOverline(DateTime(2025, 9, 11), today: today, tripStart: start), isNull);
      expect(dayOverline(DateTime(2025, 9, 16), today: today), 'TODAY');
      expect(dayOverline(DateTime(2025, 9, 1), today: today), isNull);
    });

    test('numbers days by the trip\'s calendar start date, whatever zone created it', () {
      // 16 Sep picked in Zurich (UTC+2) and in New York (UTC−4); either way Day 1 is 16 Sep.
      final fromZurich = DateTime.utc(2025, 9, 15, 22);
      final fromNewYork = DateTime.utc(2025, 9, 16, 4);
      for (final start in [fromZurich, fromNewYork]) {
        expect(dayOverline(DateTime(2025, 9, 16), today: today, tripStart: start), 'DAY 1 · TODAY');
      }
      expect(tripCalendarDate(DateTime.utc(2025, 9, 15, 11)), DateTime(2025, 9, 16), reason: 'UTC+13');
      expect(tripCalendarDate(DateTime.utc(2025, 9, 16, 10)), DateTime(2025, 9, 16), reason: 'UTC−10');
    });

    test('counts whole days across a daylight-saving change', () {
      // Europe and the US both change clocks in late October / early November.
      final autumnStart = DateTime(2025, 10, 20);
      expect(dayOverline(DateTime(2025, 11, 10), today: today, tripStart: autumnStart), 'DAY 22');
    });
  });

  test('dayHeading formats weekday, day and month', () {
    expect(dayHeading(DateTime(2025, 9, 16)), 'Tue 16 Sep');
    expect(dayHeading(DateTime(2026, 1, 4)), 'Sun 4 Jan');
  });

  test('albumDateRange collapses shared month and year', () {
    expect(albumDateRange(DateTime(2025, 9, 16, 8), DateTime(2025, 9, 16, 20)), '16 Sep');
    expect(albumDateRange(DateTime(2025, 9, 12), DateTime(2025, 9, 16)), '12–16 Sep');
    expect(albumDateRange(DateTime(2025, 8, 30), DateTime(2025, 9, 2)), '30 Aug – 2 Sep');
    expect(albumDateRange(DateTime(2025, 12, 30), DateTime(2026, 1, 2)), '30 Dec 2025 – 2 Jan 2026');
  });

  group('mosaicLayout', () {
    test('opens with a 2x2 lead and two stacked squares, lead on the requested side', () {
      expect(mosaicLayout(3, leadOnLeft: true), const [
        MosaicTile(column: 0, row: 0, columnSpan: 2, rowSpan: 2),
        MosaicTile(column: 2, row: 0),
        MosaicTile(column: 2, row: 1),
      ]);
      expect(mosaicLayout(3, leadOnLeft: false), const [
        MosaicTile(column: 0, row: 0),
        MosaicTile(column: 1, row: 0, columnSpan: 2, rowSpan: 2),
        MosaicTile(column: 0, row: 1),
      ]);
    });

    test('ends a remainder of two with a wide and a square tile, and one with a full-width tile', () {
      final eight = mosaicLayout(8, leadOnLeft: true);
      expect(eight.sublist(6), const [MosaicTile(column: 0, row: 3, columnSpan: 2), MosaicTile(column: 2, row: 3)]);

      final seven = mosaicLayout(7, leadOnLeft: false);
      expect(seven.last, const MosaicTile(column: 0, row: 3, columnSpan: 3));
    });

    test('fills small days without leaving gaps', () {
      expect(mosaicLayout(0, leadOnLeft: true), isEmpty);
      expect(mosaicLayout(1, leadOnLeft: true), const [MosaicTile(column: 0, row: 0, columnSpan: 3, rowSpan: 2)]);
      expect(mosaicLayout(2, leadOnLeft: false), const [
        MosaicTile(column: 0, row: 0, rowSpan: 2),
        MosaicTile(column: 1, row: 0, columnSpan: 2, rowSpan: 2),
      ]);
    });

    test('tiles every cell exactly once for any photo count', () {
      for (var count = 1; count <= 20; count++) {
        for (final leadOnLeft in [true, false]) {
          final tiles = mosaicLayout(count, leadOnLeft: leadOnLeft);
          final cells = tiles.expand(_cells).toList();

          expect(tiles, hasLength(count), reason: '$count photos');
          expect(cells.toSet(), hasLength(cells.length), reason: 'overlap with $count photos');
          expect(cells, hasLength(mosaicRowCount(tiles) * mosaicColumns), reason: 'gap with $count photos');
        }
      }
    });
  });
}
