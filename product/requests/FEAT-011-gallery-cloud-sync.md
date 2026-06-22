# FEAT-011: Gallery Cloud Sync Across Devices

| Field | Value |
|-------|-------|
| **ID** | FEAT-011 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Gallery is **upload-only** with local Hive cache. `GalleryRepository` has a TODO for GCP fetch. A member who uploads on phone A won't see photos on phone B; new joiners see an empty gallery.

## Proposed solution

On trip load, **list Firebase Storage** prefix `gallery/{tripId}/`, fetch metadata (and thumbnails) into Hive, merge with local optimistic uploads. Subscribe to Storage or Firestore metadata changes for live updates.

## User stories

- As a trip member, I want to see everyone's photos after joining, so the gallery feels shared.
- As a user on a new phone, I want my trip gallery restored from the cloud.

## Acceptance criteria

- [ ] Implement cloud listing in `GalleryRepository`
- [ ] Download thumbnails on trip open; lazy-fetch full res on focus view
- [ ] De-dupe by image ID with local uploads in progress
- [ ] Handle failed upload retry (see `gallery_grid.dart` TODO)

## Success metrics

- Gallery shows ≥1 remote photo within 10s of join for active trips
- Re-upload success rate > 95% after failure

## Dependencies

- FEAT-004, FEAT-014

## Related code

- `lib/features/gallery/repository/gallery_repository.dart`
- `lib/features/gallery/bloc/gallery_cubit.dart`
- `lib/features/gallery/presentation/gallery_grid.dart`

## Notes / history

- 2025-06-22: Created
