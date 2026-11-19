# FEAT-011: Gallery Cloud Sync Across Devices

| Field | Value |
|-------|-------|
| **ID** | FEAT-011 |
| **Priority** | P1 |
| **Status** | `in_progress` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Gallery is **upload-only** with local Hive cache. `uploadToGallery` puts the full-res original in Storage at `gallery/{tripId}/{uid}/{imageId}` but writes no cloud-visible record, and `fetchHighResAsset` only reads Hive. A member who uploads on phone A won't see photos on phone B; new joiners see an empty gallery.

## Proposed solution

Write a Firestore metadata doc per photo, carrying a small inline thumbnail, and have every
member's `GalleryCubit` listen to the trip's collection. The full-res original stays in
Storage and is fetched lazily when a photo is opened.

### Data model (decided)

```
galleries/{tripId}/images/{imageId} = {
  uploaderUid:  string,      // == request.auth.uid at create
  createdAt:    timestamp,   // original photo time (ImageModel.createdAt)
  uploadedAt:   timestamp,   // serverTimestamp(); ordering key
  fullUrl:      string,      // Storage download URL of the full-res original
  storagePath:  string,      // gallery/{tripId}/{uid}/{imageId}
  thumb:        bytes,       // small inline JPEG, ~10–40 KB
}
```

**Why Firestore metadata, not Storage `listAll()`:** one live `snapshots()` listener instead
of N metadata round-trips, ordering, no 1000-per-page cap, the existing `isTripMember` rules
pattern, and free offline caching. **Why an inline thumbnail:** the grid paints straight from
the snapshot with no per-image download. The existing 1080px / q70 gallery thumbnail
(~150–400 KB) is too big for a doc, so add a separate sync thumbnail (`maxEdge ≈ 384`,
`quality ≈ 50`) as new constants next to `kGalleryThumbnailMaxEdge` in
`image_compressor.dart`.

A remote doc maps to `ImageModel(id, createdAt, lowResImage: thumb, isUploading: complete,
downloadUrl: fullUrl)`, so the grid renders local and remote photos the same way with no UI
change.

### Sync rules

1. The snapshot listener is the only thing that writes gallery metadata to Hive and the only
   thing that marks a remote photo `complete`; uploads write Storage + the doc and let the
   listener echo it back.
2. Merge by image id: a local item still `uploading`/`failed` wins over its own remote echo;
   a remote id not seen locally is added from the doc; a remote `complete` for our own upload
   adopts its `downloadUrl` and keeps the richer local bytes.
3. Photos are append-only. Deletion is out of scope (separate request).
4. Cancel the listener on trip switch and in `close()`.

### Build order

1. **`GalleryService`** (`lib/features/gallery/services/gallery_service.dart`, built like
   `ItineraryService` on the named DB): `watchTripImages(tripId)` ordered by `uploadedAt`
   (tolerate a null pending server timestamp) and an idempotent `writeImageMetadata(...)`.
   Test with `fake_cloud_firestore`.
2. **Full-res fallback in `GalleryRepository`:** `fetchAndCacheFullRes(id, url)` downloads
   from `fullUrl` behind an injectable seam, caches into the per-trip high-res box.
3. **`GalleryCubit`:** subscribe in `_switchTrip`, merge per the rules above, write the
   metadata doc after a successful upload, and on a Hive miss in `fetchHighResAsset` fall back
   to `fetchAndCacheFullRes`. Keep the existing no-arg test constructors working.
4. **Firestore rules** for `galleries/{tripId}/images/{imageId}`: member read; create only by
   a member with `uploaderUid == request.auth.uid`, an allow-listed key set,
   `uploadedAt == request.time`, `thumb is bytes` under the doc cap; no update/delete. Storage
   rules already allow members to read the full-res path. Run the security-rules auditor;
   rules deploy is tracked separately.
5. **Failed-upload retry** in `_CompactGrid` (`lib/screens/gallery_page.dart`): a retry
   affordance on `failed` tiles calling a new `GalleryCubit.retryUpload(id)` that re-uploads
   from the cached high-res blob and writes the doc.

Steps 1–4 are one PR (cloud listing, thumbnails, de-dupe); step 5 is a second (retry).

## User stories

- As a trip member, I want to see everyone's photos after joining, so the gallery feels shared.
- As a user on a new phone, I want my trip gallery restored from the cloud.

## Acceptance criteria

- [ ] Implement cloud listing in `GalleryRepository`
- [ ] Download thumbnails on trip open; lazy-fetch full res on focus view
- [ ] De-dupe by image ID with local uploads in progress
- [ ] Handle failed upload retry on `failed` tiles in the gallery grid

## Success metrics

- Gallery shows ≥1 remote photo within 10s of join for active trips
- Re-upload success rate > 95% after failure

## Dependencies

- FEAT-004, FEAT-014

## Related code

- `lib/features/gallery/repository/gallery_repository.dart`
- `lib/features/gallery/bloc/gallery_cubit.dart`
- `lib/features/gallery/services/image_compressor.dart`
- `lib/features/gallery/presentation/gallery_focus_view.dart`
- `lib/screens/gallery_page.dart` — `_CompactGrid`
- `infra/rules/firestore.rules`, `infra/rules/storage.rules`

## Open questions

- Does `maxEdge 384 / q50` stay well under the doc cap on real photos? Tune if not.
- Add `uploaderUid` to `ImageModel` now (cheap, enables attribution) or later? Appending it
  means a new field at the end of the hand-written Hive adapter.
- Paginate the listener for very large galleries? Defer unless trips routinely pass a few
  hundred photos.

## Notes / history

- 2025-06-22: Created
- 2026-11-17: Replaced the Storage-listing approach with Firestore metadata + inline
  thumbnails, added sync rules and build order. Ready for development.
- 2026-11-19: Built on `julius/photos-revamp`: `GalleryService`, listener + merge in
  `GalleryCubit`, sync thumbnail, Firestore rules, retry on failed tiles. Two changes from
  the plan above: full-res originals are cached as files under
  `<app support>/gallery/{tripId}/{imageId}.jpg` instead of a Hive box (a regular box loads
  every original into memory), and a remote doc always marks a photo `complete`, since the
  doc only exists once the upload succeeded. `ImageModel` gained `uploaderUid`. Also adds
  "Save all to Photos" (album `Xplore – <trip>`, via `gal`). Rules **deploy** and the
  gallery UI redesign are still open.
