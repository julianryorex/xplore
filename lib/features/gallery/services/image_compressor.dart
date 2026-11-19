import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pure-Dart gallery thumbnail compression.
///
/// We deliberately keep the full-resolution original untouched (it is what
/// uploads to Firebase Storage so other members see the full-detail photo).
/// This only produces the smaller `lowResImage` that is cached in Hive and
/// rendered in the local gallery grid for fast, low-memory display, plus a
/// much smaller sync thumbnail that is inlined in the photo's Firestore
/// metadata doc so other members' grids paint without a download (FEAT-011).
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

/// Longest-edge (px) cap for the sync thumbnail inlined in Firestore.
const int kGallerySyncThumbnailMaxEdge = 384;

/// JPEG quality (0–100) for the sync thumbnail inlined in Firestore.
const int kGallerySyncThumbnailQuality = 50;

/// Byte budget for the sync thumbnail. Keeps the doc far below Firestore's
/// 1 MiB cap and must match the `thumb.size()` bound in `firestore.rules`.
const int kGallerySyncThumbnailMaxBytes = 256 * 1024;

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

/// Produces the small JPEG inlined in a photo's Firestore metadata doc.
///
/// Returns `null` when the result would exceed [kGallerySyncThumbnailMaxBytes]
/// (e.g. an undecodable source returned as-is), since the rules would reject it.
Future<Uint8List?> compressGallerySyncThumbnailAsync(Uint8List bytes) async {
  final thumb = await compressGalleryThumbnailAsync(
    bytes,
    maxEdge: kGallerySyncThumbnailMaxEdge,
    quality: kGallerySyncThumbnailQuality,
  );
  return thumb.lengthInBytes <= kGallerySyncThumbnailMaxBytes ? thumb : null;
}

/// Whether [bytes] is a sync thumbnail that is safe to decode: a JPEG within
/// [kGallerySyncThumbnailMaxBytes] whose declared size fits [kGallerySyncThumbnailMaxEdge].
///
/// Another member wrote these bytes and the rules can only bound their length, so a
/// tiny file declaring huge dimensions would otherwise exhaust memory when painted.
bool isAcceptableSyncThumbnail(Uint8List bytes) {
  if (bytes.lengthInBytes > kGallerySyncThumbnailMaxBytes) return false;
  try {
    // startDecode only parses the headers; it allocates no pixel buffers.
    final info = img.JpegDecoder().startDecode(bytes);
    return info != null &&
        info.width > 0 &&
        info.height > 0 &&
        info.width <= kGallerySyncThumbnailMaxEdge &&
        info.height <= kGallerySyncThumbnailMaxEdge;
  } catch (_) {
    return false;
  }
}

/// When the photo in [bytes] was taken, read from its EXIF data, or `null` when
/// it carries none.
///
/// The picker hands over a temporary copy whose file dates are the moment of
/// picking, so EXIF is the only record of the day a photo belongs to. EXIF has
/// no time zone; the value is read as device-local time.
DateTime? readPhotoTakenAt(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    final taken = exif?.exifIfd['DateTimeOriginal']?.toString() ?? exif?.imageIfd['DateTime']?.toString();
    // EXIF dates look like "2026:09:16 18:42:07".
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(taken ?? '');
    if (match == null) return null;

    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    // Cameras without a set clock write all zeros.
    if (parts[0] == 0 || parts[1] == 0 || parts[2] == 0) return null;
    return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  } catch (_) {
    return null;
  }
}
