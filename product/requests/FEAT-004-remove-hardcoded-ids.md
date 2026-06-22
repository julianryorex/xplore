# FEAT-004: Replace Hardcoded Trip/User IDs

| Field | Value |
|-------|-------|
| **ID** | FEAT-004 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | M |
| **Owner** | — |

## Problem

Production paths and demo assumptions are scattered:

- `itineraryId = 'ph4kd'` and `userId = '7d125e54-...'` in constants
- Gallery uploads to `gallery/ph4kd/`
- Location sync to `locations/ph4kd`
- Demo itinerary lookup hardcodes `ph4kd`

This prevents multi-user, multi-trip operation and creates data leakage risk if shipped as-is.

## Proposed solution

Centralize **active trip ID** and **current user ID** in `TripCubit` and `AuthCubit`. Inject or read via `context.read<>()` in cubits. Remove constants from `lib/constants/constants.dart` (or limit to theme/padding only). Keep demo mode behind a dev flag or `loadDemoItinerary()` for tests only.

## User stories

- As a developer, I want one source of truth for trip context, so features stay consistent.
- As a user, my photos and location only appear under my trip, not a shared demo bucket.

## Acceptance criteria

- [ ] No production code imports hardcoded `itineraryId` / `userId` from constants
- [ ] `LocationCubit`, `GalleryCubit`, `ProfileCubit`, `MapCubit` use dynamic IDs
- [ ] Firebase paths parameterized: `locations/{tripId}/{userId}`, `gallery/{tripId}/`
- [ ] Demo JSON load isolated to debug/test entry points
- [ ] `flutter analyze` clean; existing smoke tests updated

## Success metrics

- Zero cross-trip data incidents in QA
- All integration tests use injectable trip/user fixtures

## Dependencies

- FEAT-001, FEAT-002 (can start refactor in parallel with interfaces/stubs)

## Related code

- `lib/constants/constants.dart`
- `lib/features/gallery/bloc/gallery_cubit.dart` — line 156 `gallery/ph4kd/`
- `lib/features/location/bloc/location_cubit.dart` — `locations/$itineraryId`
- `lib/features/itinerary/bloc/itinerary_cubit.dart` — `ph4kd` lookup

## Open questions

- Migrate existing demo Firebase data or fresh namespaces per env?

## Notes / history

- 2025-06-22: Created
