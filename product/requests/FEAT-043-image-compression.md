# FEAT-043: Re-enable Image Compression (iOS 26)

| Field | Value |
|-------|-------|
| **ID** | FEAT-043 |
| **Priority** | P4 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | S |
| **Owner** | — |

## Problem

`flutter_image_compress` disabled in `pubspec.yaml` due to iOS 26 SDK dropping AssetsLibrary. Gallery uploads full-resolution bytes — higher Storage cost and slower sync.

## Proposed solution

Re-enable when plugin supports iOS 26, or swap to alternative compressor. Restore 50% compression path in `GalleryCubit.uploadToGallery`.

## Related code

- `pubspec.yaml`, `lib/features/gallery/bloc/gallery_cubit.dart`

## Notes / history

- 2025-06-22: Created
- 2026-06-23: Clarified scope — `flutter_image_compress` was **gallery-only**; it was
  never part of the profile-on-map avatar pipeline. See
  [FEAT-046](./FEAT-046-map-avatar-marker-pipeline.md), which proposes a pure-Dart
  (`image` package) resize utility that could supersede this native dependency.
