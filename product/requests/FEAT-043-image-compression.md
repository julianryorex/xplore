# FEAT-043: Re-enable Image Compression (iOS 26)

| Field | Value |
|-------|-------|
| **ID** | FEAT-043 |
| **Priority** | P4 |
| **Status** | `done` |
| **Revenue impact** | indirect |
| **Effort** | S |
| **Owner** | — |

## Problem

`flutter_image_compress` was disabled in `pubspec.yaml` because the iOS 26 SDK dropped the AssetsLibrary framework it relied on. While disabled, the gallery cached the full-resolution bytes as the local thumbnail — higher memory use and no fast low-res display.

## Proposed solution

~~Re-enable when plugin supports iOS 26, or swap to alternative compressor.~~
**Resolved:** swapped to the pure-Dart [`image`](https://pub.dev/packages/image) package (no native plugin, immune to iOS SDK churn). `GalleryCubit.uploadToGallery` now builds the `lowResImage` thumbnail via `compressGalleryThumbnailAsync` (downscale longest edge ≤1080 px, JPEG q70, run on a background isolate). The **full-resolution original is intentionally left untouched** and still uploaded to Storage so other members see the full-detail image.

## Related code

- `pubspec.yaml` — `image: ^4.8.0` (replaces `flutter_image_compress`)
- `lib/features/gallery/services/image_compressor.dart` — pure-Dart thumbnail compressor
- `lib/features/gallery/bloc/gallery_cubit.dart` — `uploadToGallery`
- `test/gallery_image_compressor_test.dart` — unit tests

## Notes / history

- 2025-06-22: Created
- 2026-06-23: Clarified scope — `flutter_image_compress` was **gallery-only**; it was
  never part of the profile-on-map avatar pipeline. See
  [FEAT-046](./FEAT-046-map-avatar-marker-pipeline.md).
- 2026-06-23: **Done** — replaced the removed native plugin with the pure-Dart `image`
  package for gallery thumbnail compression (full-resolution upload preserved).
