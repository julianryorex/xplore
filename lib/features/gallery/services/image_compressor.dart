import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pure-Dart gallery thumbnail compression.
///
/// We deliberately keep the full-resolution original untouched (it is what
/// uploads to Firebase Storage so other members see the full-detail photo).
/// This only produces the smaller `lowResImage` that is cached in Hive and
/// rendered in the local gallery grid for fast, low-memory display.
///
/// Implemented with the pure-Dart [`image`](https://pub.dev/packages/image)
/// package instead of `flutter_image_compress` so there is no native plugin to
/// break when the iOS SDK changes (the original reason compression was
/// disabled — the iOS 26 SDK dropped the AssetsLibrary framework that plugin
/// relied on).

/// Longest-edge (px) cap for the cached gallery thumbnail.
const int kGalleryThumbnailMaxEdge = 1080;

/// JPEG quality (0–100) for the cached gallery thumbnail.
const int kGalleryThumbnailQuality = 70;

/// Arguments for [compressGalleryThumbnail], packaged so the work can be run on
/// a background isolate via [compute] (which passes a single argument).
@immutable
class ThumbnailRequest {
  final Uint8List bytes;
  final int maxEdge;
  final int quality;

  const ThumbnailRequest(
    this.bytes, {
    this.maxEdge = kGalleryThumbnailMaxEdge,
    this.quality = kGalleryThumbnailQuality,
  });
}

/// Decodes [request.bytes], downscales so the longest edge is at most
/// [ThumbnailRequest.maxEdge] (preserving aspect ratio), and re-encodes as
/// JPEG. EXIF orientation is baked in so the thumbnail is displayed upright.
///
/// Returns the original bytes unchanged if decoding fails (e.g. an unsupported
/// format) so an upload is never blocked by a thumbnail failure. The result is
/// only smaller-or-equal when the source is already within bounds and cheaper
/// to encode; callers should treat this purely as a display thumbnail.
///
/// This is a top-level, side-effect-free function so it is safe to hand to
/// [compute].
Uint8List compressGalleryThumbnail(ThumbnailRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return request.bytes;

  // Bake in EXIF rotation, otherwise the re-encoded JPEG can appear sideways.
  final oriented = img.bakeOrientation(decoded);

  final int longestEdge = oriented.width >= oriented.height ? oriented.width : oriented.height;

  final img.Image resized = longestEdge > request.maxEdge
      ? img.copyResize(
          oriented,
          // Constrain the longer side; the other is scaled to keep aspect.
          width: oriented.width >= oriented.height ? request.maxEdge : null,
          height: oriented.height > oriented.width ? request.maxEdge : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;

  return img.encodeJpg(resized, quality: request.quality);
}

/// Runs [compressGalleryThumbnail] on a background isolate so large images do
/// not jank the UI thread. Falls back to the original bytes on any error.
Future<Uint8List> compressGalleryThumbnailAsync(
  Uint8List bytes, {
  int maxEdge = kGalleryThumbnailMaxEdge,
  int quality = kGalleryThumbnailQuality,
}) async {
  try {
    return await compute(compressGalleryThumbnail, ThumbnailRequest(bytes, maxEdge: maxEdge, quality: quality));
  } catch (_) {
    return bytes;
  }
}
