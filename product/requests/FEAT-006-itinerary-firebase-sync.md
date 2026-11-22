# FEAT-006: Production Itinerary Data Layer

| Field | Value |
|-------|-------|
| **ID** | FEAT-006 |
| **Priority** | P0 |
| **Status** | `in_progress` |
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

- [x] Load itinerary from cloud by `TripCubit.activeTripId`
- [x] Real-time sync when another member edits (or optimistic with conflict strategy)
- [ ] Create/edit/delete daily plan and location (owner-only today; owner and admins once FEAT-024 lands)
  — completion toggle shipped in #107; add/edit/delete still to do
- [x] Offline read cache via Hive for airplane mode
- [x] Demo loader remains for `test/itinerary_demo_smoke_test.dart`

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

## Decisions (locked)

- **Single document, whole-array writes.** Edits are an immutable read-modify-write of the
  embedded `daily_plans` array (`itinerary.copyWith(...)` → `ItineraryService.writeDailyPlans`,
  which uses `update`, not `set`, so a missing doc errors instead of dropping `invitees`/`pins`).
  No `arrayUnion`/`arrayRemove`: they need exact element matches and break on nested objects.
- **Firestore is the source of truth; Hive is a passive cache.** Mutators write Firestore
  only; the snapshot listener is the only thing that emits and writes Hive, so the cache never
  holds a half-applied edit.
- **Last-write-wins, no version field** for now. With owner-only editing there is one editor,
  so contention is negligible. Revisit when FEAT-024 adds admins as co-editors; the editor set
  stays small (owner plus the admins they promote), never the whole group.
- **Owner-only editing** (`trips/{tripId}.createdBy`), enforced three times: the
  `validItineraryUpdate` rule (authoritative; only `daily_plans`, `pins`, `last_updated` may
  change, `invitees` stays immutable), `ItineraryCubit.canEdit` (mutators no-op for
  non-owners), and the UI (edit chrome hidden unless `canEdit`). Whole-itinerary delete stays
  denied.
- **Editing never opens to all members.** FEAT-024 widens the gate from "owner" to "owner or
  admin" in the same three places; members stay read-only. Build the CRUD below against a
  single `canEdit` check so that widening is a one-line change in the cubit and the rule.

## Remaining work

1. **Day/stop CRUD in `ItineraryCubit`** — `addLocation` / `updateLocation` /
   `removeLocation`, `addDay` / `updateDay` / `removeDay` (optional `reorderDays`), all as
   transforms over the loaded model funnelled through `writeDailyPlans`, gated on `canEdit`.
   Add an `isSaving` / `saveError` signal on `LoadedItineraryState` (not a separate state that
   hides the plan). Keep the no-arg demo constructor working.
2. **Edit UI** — a bottom-sheet stop editor (name, description; empty `place_id` for manual
   stops), swipe/long-press delete, "Add stop" and day add/edit from the overview. Show
   `saveError` with a retry. Gate everything on `canEdit` so members and goldens keep the
   read-only view. Closes #40 together with step 1.
3. **Editable generated plan before creation** (FEAT-007 follow-up) — reuse the stop/day
   editor against the in-memory draft in the create flow so tweaks are seeded via
   `seedItinerary(dailyPlans:)`; editing the review must not trigger regeneration. The create
   flow is being replaced, so design this against the new flow, not
   `create_trip_review_steps.dart`.
4. **`place_id` enrichment** (optional, own PR) — generated and manual stops have an empty
   `place_id`; resolve lazily with a Places text search on name + location and tolerate empty
   ids until then. Gated on Places billing.

## Open questions

- None. Last-write-wins stays when FEAT-024 adds admins as co-editors (decided 2026-11-22);
  each change records who made it and when, without showing it in the app yet.

## Notes / history

- 2025-06-22: Created
- 2026-11-17: Resolved the data-shape and conflict questions, recorded the owner-only editing
  model shipped in #107 (completion toggle), and added the remaining CRUD plan.
- 2026-11-22: Editing will widen to owner and admins only (FEAT-024), not to every member.
