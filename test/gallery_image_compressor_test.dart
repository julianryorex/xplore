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
}
