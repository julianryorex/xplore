# FEAT-046: Profile Avatar Map-Marker Pipeline (post image-compression removal)

| Field | Value |
|-------|-------|
| **ID** | FEAT-046 |
| **Priority** | P4 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

We removed/disabled `flutter_image_compress` because the iOS 26 SDK dropped the
AssetsLibrary framework the plugin depends on (see `pubspec.yaml` lines 22–26 and
[FEAT-043](./done/FEAT-043-image-compression.md)). The open question raised was: image
compression was thought to power the "profile photo on the map" feature
(Apple-Maps-style avatar pins), so does removing it hurt that feature, and is
compressing an image even the right way to render a profile neatly on the map?

**Key finding from the code audit — the premise needs correcting:**

`flutter_image_compress` was **only ever used by the gallery**, never by the
profile-on-map avatar. The two are unrelated code paths:

- **Gallery (used compression):** `GalleryCubit.uploadToGallery` compressed picked
  photos ~50% to build `lowResImage` thumbnails before caching/upload. That path is
  now stubbed to `file.readAsBytes()` (`lib/features/gallery/bloc/gallery_cubit.dart`
  lines 83–93). This is the concern tracked by FEAT-043.
- **Profile-on-map avatar (never used compression):** the avatar pin is produced by
  rasterizing a Flutter widget, not by compressing a photo:
  1. `ProfileCubit.changeProfilePicture` picks a photo with `ImagePicker.pickImage`
     and stores the **full-resolution** bytes
     (`lib/features/profile/bloc/profile_cubit.dart` line ~39 — no `maxWidth`,
     `maxHeight`, or `imageQuality`).
  2. Those bytes feed the shared `AvatarMapIcon` widget (100 logical px circle with a
     4 px white ring — `lib/core/avatar_map_icon.dart`).
  3. `MarkerService.convertMarkerWidgetToBytes` captures that widget via
     `RepaintBoundary.toImage(pixelRatio: 1.5)` → `ImageByteFormat.png`, producing a
     ~150×150 PNG (`lib/features/map/services/marker_service.dart` lines 25–38).
  4. The PNG is cached in Hive (`markers` box, keyed by user id) and uploaded to
     Firebase Storage at `markers/{id}/marker`.
  5. `MapCubit.updateUserMarkers` reads the PNG from Hive and builds the pin with
     `BitmapDescriptor.bytes(...)`, falling back to `BitmapDescriptor.defaultMarker`
     (`lib/features/map/bloc/map_cubit.dart` lines 65–86).

**Therefore:** removing `flutter_image_compress` did **not** break the
profile-on-map feature, and "compressing an image" was never how that pin was built.
The real, separate issues worth fixing in this pipeline are:

1. **Unbounded source image.** Profile photos are picked and stored at full
   resolution (memory + `profile_picture.png` on disk can be many MB). The (disabled)
   compression that helped the gallery never applied here.
2. **Single static `GlobalKey`.** `AvatarMapIcon.globalKeyAvatarMapIcon` is a single
   static key, so only one avatar can be rasterized at a time and only while the
   widget happens to be mounted. This is why peers tend to show the default red pin.
3. **Crispness is hard-coded.** `pixelRatio: 1.5` ignores the real device pixel ratio,
   so the pin can look soft on 3x displays and oversized on 1x.
4. **No cross-device avatar fetch.** The marker PNG is uploaded to Storage but never
   downloaded by other clients (the `downloadURL` is discarded). This is owned by
   [FEAT-015](./FEAT-015-profile-cloud-sync.md).

## Proposed solution

Treat the map avatar as a **rendered bitmap problem, not a compression problem.** Bound
the source photo at pick time, render the marker bitmap deterministically (off-screen,
device-aware, no shared `GlobalKey`), and produce a small synced avatar thumbnail using
a pure-Dart codec so we are not blocked by native iOS-SDK churn again. The options below
are ordered roughly by effort; the recommendation combines the cheapest high-leverage
ones.

### Option A — Bound the source image at pick time (no new dependency)

`ImagePicker.pickImage` already accepts `maxWidth`, `maxHeight`, and `imageQuality`,
which the OS-native picker applies (works on iOS 26). Pick the profile photo at, e.g.,
`maxWidth: 512, maxHeight: 512, imageQuality: 85`.

- **Pros:** One-line change; eliminates the multi-MB full-res profile bytes that were
  the real waste; no plugin, no iOS-SDK risk; speeds up widget rasterization.
- **Cons:** Resizes the photo everywhere it's used (profile page, home header), so we
  keep one bounded master rather than separate hi-res/thumbnail variants. Acceptable —
  the profile photo is only ever shown small.

### Option B — Make the existing widget-rasterization pipeline robust & device-aware

Keep `RepaintBoundary.toImage` (it already yields a tiny bitmap and needs no
compression), but: (1) replace the single static `GlobalKey` with a per-render key (or
render off-screen), so any user's avatar can be generated on demand; (2) use the real
`MediaQuery.devicePixelRatio` (clamped) instead of the hard-coded `1.5`; (3) generate
the marker without depending on a mounted on-screen widget.

- **Pros:** Builds on existing, working code; fixes the "everyone is a red pin" and
  soft-rendering bugs; no new deps.
- **Cons:** `toImage` of a real widget still requires a render tree; off-screen
  rendering needs care (`PipelineOwner`/`BuildOwner` or a transient overlay).

### Option C — Pure-Dart resize/encode with the `image` package (no native deps)

Add the pure-Dart [`image`](https://pub.dev/packages/image) package to decode → resize
→ re-encode (JPEG/WebP) a small avatar thumbnail (e.g. 256×256). Because it's pure Dart,
it is immune to the iOS-26 AssetsLibrary problem that sidelined `flutter_image_compress`.

- **Pros:** Cross-platform, no native build risk; gives us an explicit small avatar
  variant to sync to peers (feeds FEAT-015); the same utility could also re-enable the
  gallery thumbnail path and resolve FEAT-043 without a native plugin.
- **Cons:** Pure-Dart resize is slower than native (run off the UI isolate via
  `compute`); adds a dependency (lighter risk than a native one).

### Option D — Canvas-composited marker via `dart:ui` Canvas / CustomPainter

Draw the pin directly on a `Canvas` (circle-cropped avatar + white ring + optional
drop-shadow / pin tail), then `Picture.toImage(w, h)` → PNG. This is the canonical
Google-Maps custom-marker technique and removes the dependency on a mounted widget and
the shared `GlobalKey` entirely.

- **Pros:** Full Apple-Maps-style control (shape, shadow, status ring for stale/active);
  deterministic exact-pixel sizing; no widget tree, no `GlobalKey`; pairs naturally with
  FEAT-017 (last-seen state ring).
- **Cons:** More code than Option B; we hand-draw the styling that the widget gave for
  free.

### Option E — Server-side image transformation (Storage / Cloud Function)

Upload the avatar once and let the Firebase "Resize Images" extension (or a Cloud
Function) generate sized variants (e.g. 128 px) in Storage; clients download the small
URL variant for markers.

- **Pros:** Smallest client bandwidth/CPU; clean cross-device sync; clients hold only a
  URL.
- **Cons:** Backend infra + cost; depends on auth/cloud profile model
  ([FEAT-001](./done/FEAT-001-user-authentication.md), FEAT-015); overkill on its own for a
  ~150 px pin.

## Recommended approach

**A + B now, with C as the shared utility; D as a fast-follow; defer E to FEAT-015.**

1. **Option A (pick-time bound)** — immediately stop storing full-res profile bytes
   (`maxWidth/maxHeight: 512`, `imageQuality: 85`). Highest value for least effort and
   directly addresses the only place a "compression"-like step was actually missing for
   profile.
2. **Option B (robust rasterization)** — drop the shared static `GlobalKey`, render the
   marker off-screen, and size by real device pixel ratio. This is the core "better way
   to display a profile neatly on the map" fix and unblocks rendering peers' avatars.
3. **Option C (`image` package)** — add a small pure-Dart resize utility to emit a
   256 px avatar thumbnail for cross-device sync, chosen specifically so we are never
   again blocked by a native iOS-SDK change. **Done for the gallery** — see
   `lib/features/gallery/services/image_compressor.dart` (introduced for FEAT-043);
   the avatar path can reuse the same utility.
4. **Option D** — adopt the Canvas painter when we add styled status rings (aligns with
   FEAT-017) for pixel-perfect, widget-free pins.
5. **Option E** — only if/when avatar serving cost becomes material, folded into the
   FEAT-015 cloud-profile work.

**Net:** the map-marker pin needs *bitmap rendering*, not an image-compression library.
`flutter_image_compress` is purely a gallery concern (FEAT-043) and can itself be
replaced by the pure-Dart `image` package.

## User stories

- As a trip member, I want to see each person's photo on the map (not a generic red
  pin), so I can tell at a glance who is where.
- As a user, I want my profile photo to render crisply and load fast on the map, so the
  map feels as polished as Apple Maps.
- As a developer, I want the avatar pipeline to not depend on a native plugin that
  breaks on iOS SDK bumps, so the feature stays stable across SDK upgrades.

## Acceptance criteria

- [ ] Profile photos are bounded at pick time (e.g. ≤512×512, quality ~85); no
      full-resolution profile bytes are stored in state or on disk.
- [ ] Marker bitmaps render at the device pixel ratio and no longer rely on a single
      shared static `GlobalKey` (more than one user's avatar can be generated).
- [ ] A pure-Dart resize utility (`image` package or equivalent) produces avatar
      thumbnails with no native iOS-SDK dependency.
- [ ] Documented decision: the map-marker path does not require `flutter_image_compress`;
      FEAT-043 is re-scoped to gallery-only (or superseded by the pure-Dart utility).
- [ ] Peers' avatars can render once their bitmap is available locally or via FEAT-015
      sync (no silent fallback to the default pin when an avatar exists).

## Success metrics

- Stored profile-photo size drops from full-res (often >1 MB) to <100 KB.
- Map shows custom avatars for users with a known photo (not the default pin).
- No iOS build break from avatar image handling across SDK upgrades.

## Dependencies

- [FEAT-015](./FEAT-015-profile-cloud-sync.md) — cross-device avatar fetch (download the
  uploaded marker / avatar by URL).
- [FEAT-017](./FEAT-017-map-marker-info.md) — styled marker state (pairs with Option D).
- [FEAT-043](./done/FEAT-043-image-compression.md) — gallery compression; **done** via the
  pure-Dart `image` package, whose `image_compressor.dart` utility the avatar path can
  reuse.

## Related code

- `pubspec.yaml` — lines 22–26, `flutter_image_compress` commented out.
- `lib/features/profile/bloc/profile_cubit.dart` — `changeProfilePicture` picks full-res
  bytes; `saveProfilePicture` / `loadProfileInState` write `profile_picture.png`.
- `lib/core/avatar_map_icon.dart` — `AvatarMapIcon` + single static `globalKeyAvatarMapIcon`.
- `lib/features/map/services/marker_service.dart` — `convertMarkerWidgetToBytes`
  (`toImage(pixelRatio: 1.5)`), Hive cache, `uploadMarkerIcon` (discards `downloadURL`).
- `lib/features/map/bloc/map_cubit.dart` — `updateUserMarkers` (`BitmapDescriptor.bytes`
  vs `defaultMarker`).
- `lib/features/gallery/bloc/gallery_cubit.dart` — lines 83–93, disabled compression
  fallback (gallery, FEAT-043 scope).
- `lib/utilities/utilities.dart` — unused `getBytesFromAsset` (already has a pure-`dart:ui`
  resize via `instantiateImageCodec(targetWidth:)`) and `getMarkerIconFromBytes`.

## Open questions

- Do we want one bounded master profile image (Option A) or a separate hi-res original +
  generated thumbnail (A + C)? Master-only is simpler and sufficient today.
- ~~Should the gallery thumbnail path (FEAT-043) be folded into the same pure-Dart
  utility?~~ Done — FEAT-043 now uses `image_compressor.dart`; the avatar work should
  reuse it.

## Notes / history

- 2026-06-23: Created from Slack request (#xplore-feature-requests). Audit confirmed
  `flutter_image_compress` was gallery-only and never part of the profile-on-map avatar
  pipeline; reframed the work as a bitmap-rendering improvement rather than a
  compression re-enable.
