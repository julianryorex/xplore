# FEAT-006: Production Itinerary Data Layer

| Field | Value |
|-------|-------|
| **ID** | FEAT-006 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |

## Problem

Itineraries only load from bundled `assets/demo/itinerary.json`. Organizers cannot edit plans, and changes don't sync to trip members. The UI (carousel, overview, focus pages) is production-quality but backed by static demo data.

## Proposed solution

Persist itineraries in Firebase (Firestore recommended for nested `daily_plans`). Extend `ItineraryCubit` with: load by active trip ID, real-time listener for member edits, CRUD for days and locations. Keep Freezed models; align JSON shape with existing demo schema for migration ease.

## User stories

- As an organizer, I want to add/edit stops on a day plan, so the group sees updates instantly.
- As a member, I want the home carousel to reflect live trip data, not demo JSON.
- As a developer, I want `loadDemoItinerary()` preserved for tests and golden screenshots.

## Acceptance criteria

- [ ] Load itinerary from cloud by `TripCubit.activeTripId`
- [ ] Real-time sync when another member edits (or optimistic with conflict strategy)
- [ ] Create/edit/delete daily plan and location (organizer-only initially — FEAT-024)
- [ ] Offline read cache via Hive for airplane mode
- [ ] Demo loader remains for `test/itinerary_demo_smoke_test.dart`

## Success metrics

- Itinerary load p95 < 2s on LTE
- Edit sync visible to second device < 5s

## Dependencies

- FEAT-002, FEAT-004

## Related code

- `lib/features/itinerary/bloc/itinerary_cubit.dart`
- `lib/features/itinerary/models/itinerary_models.dart`
- `assets/demo/itinerary.json` — schema reference
- `lib/screens/itinerary_overview_page.dart`, `itinerary_focus_page.dart`

## Open questions

- Firestore subcollections vs. single document with embedded arrays?
- Version field for optimistic locking on concurrent edits?

## Notes / history

- 2025-06-22: Created
