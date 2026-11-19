// Unit tests for the pure-Dart gallery thumbnail compressor.
//
// These run headlessly on Linux/CI (no Firebase, GPU or GUI) and exercise the
// real `compressGalleryThumbnail` path against a bundled asset image, verifying
// that thumbnails are downscaled and re-encoded while leaving the original
// untouched.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xplore/features/gallery/services/image_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  test('downscales a large photo so the longest edge fits maxEdge', () async {
    final original = await loadAsset('assets/placeholders/skytree.jpeg');
    final source = img.decodeImage(original)!;
    final sourceLongest = source.width >= source.height ? source.width : source.height;

    const maxEdge = 256;
    final thumb = compressGalleryThumbnail(ThumbnailRequest(original, maxEdge: maxEdge, quality: 70));

    final decoded = img.decodeImage(thumb)!;
    final thumbLongest = decoded.width >= decoded.height ? decoded.width : decoded.height;

    // Only meaningful if the source was actually larger than the cap.
    expect(sourceLongest, greaterThan(maxEdge));
    expect(thumbLongest, lessThanOrEqualTo(maxEdge));
    // Aspect ratio preserved within a 1px rounding tolerance.
    expect(decoded.width / decoded.height, closeTo(source.width / source.height, 0.02));
    // A downscaled JPEG thumbnail should be smaller than the original bytes.
    expect(thumb.lengthInBytes, lessThan(original.lengthInBytes));
  });

  test('does not upscale an image already within bounds', () async {
    final original = await loadAsset('assets/placeholders/skytree.jpeg');
    final source = img.decodeImage(original)!;
    final sourceLongest = source.width >= source.height ? source.width : source.height;

    final thumb = compressGalleryThumbnail(ThumbnailRequest(original, maxEdge: sourceLongest + 1000, quality: 70));

    final decoded = img.decodeImage(thumb)!;
    expect(decoded.width, source.width);
    expect(decoded.height, source.height);
  });

  test('returns original bytes unchanged when decoding fails', () {
    final garbage = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
    final result = compressGalleryThumbnail(ThumbnailRequest(garbage));

    expect(result, same(garbage));
  });

  group('compressGallerySyncThumbnailAsync', () {
    test('shrinks a full-size camera photo well under the Firestore doc cap', () async {
      final original = await loadAsset('assets/placeholders/skating.JPG');

      final thumb = await compressGallerySyncThumbnailAsync(original);

      expect(thumb, isNotNull);
      final decoded = img.decodeImage(thumb!)!;
      expect(decoded.width >= decoded.height ? decoded.width : decoded.height, kGallerySyncThumbnailMaxEdge);
      expect(thumb.lengthInBytes, lessThan(100 * 1024));
    });

    test('returns null instead of an oversized undecodable payload', () async {
      final garbage = Uint8List(kGallerySyncThumbnailMaxBytes + 1);

      expect(await compressGallerySyncThumbnailAsync(garbage), isNull);
    });
  });

  group('isAcceptableSyncThumbnail', () {
    test('accepts a JPEG within the sync thumbnail bounds', () {
      expect(
        isAcceptableSyncThumbnail(img.encodeJpg(img.Image(width: kGallerySyncThumbnailMaxEdge, height: 10))),
        isTrue,
      );
    });

    test('rejects non-JPEG and undecodable bytes', () {
      expect(isAcceptableSyncThumbnail(img.encodePng(img.Image(width: 8, height: 8))), isFalse);
      expect(isAcceptableSyncThumbnail(Uint8List.fromList([0xff, 0xd8, 0xff, 0xc0, 0, 1])), isFalse);
    });

    test('rejects a small file that declares huge dimensions, without decoding its pixels', () {
      final bomb = img.encodeJpg(img.Image(width: 8, height: 8));
      // Rewrite the SOF0 frame header (FF C0, length, precision, height, width) to 30000x30000.
      final sof = List.generate(bomb.length - 1, (i) => i).firstWhere((i) => bomb[i] == 0xff && bomb[i + 1] == 0xc0);
      for (final offset in [sof + 5, sof + 7]) {
        bomb[offset] = 30000 >> 8;
        bomb[offset + 1] = 30000 & 0xff;
      }

      expect(isAcceptableSyncThumbnail(bomb), isFalse);
    });
  });

  group('readPhotoTakenAt', () {
    Uint8List jpegTakenAt(String? exifDate) {
      final image = img.Image(width: 4, height: 4);
      if (exifDate != null) image.exif.exifIfd['DateTimeOriginal'] = img.IfdValueAscii(exifDate);
      return img.encodeJpg(image);
    }

    test('reads the capture time from EXIF', () {
      expect(readPhotoTakenAt(jpegTakenAt('2025:09:16 18:42:07')), DateTime(2025, 9, 16, 18, 42, 7));
    });

    test('is null for photos without a usable capture time', () {
      expect(readPhotoTakenAt(jpegTakenAt(null)), isNull);
      expect(readPhotoTakenAt(jpegTakenAt('0000:00:00 00:00:00')), isNull);
      expect(readPhotoTakenAt(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });
}
