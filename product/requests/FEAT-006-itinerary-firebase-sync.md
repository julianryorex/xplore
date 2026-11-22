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
- [x] Create/edit/delete daily plan and location (owner-only today; owner and admins once FEAT-024 lands)
  — completion toggle shipped in #107; add, edit, delete and reorder of stops and add, rename and remove
  of days shipped with stage 1 of the [trip roles rollout](../TRIP_ROLES_ROLLOUT.md)
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

## Shipped in stage 1 (owner editing)

- **Day/stop CRUD in `ItineraryCubit`** — `addLocation` / `updateLocation` / `removeLocation` /
  `reorderLocations`, `addDay` / `renameDay` / `removeDay`, all transforms over the loaded model
  funnelled through `writeDailyPlans` and gated on the single `_canEdit` check. `LoadedItineraryState`
  carries `isSaving` and `saveFailure`; the plan shows an edit at once and keeps showing it after a
  failed save (the unsaved stop is marked "Not saved") until `retrySave()` goes through.
- **Edit UI** — restyled day page with an "Add stop" row, a stop editor sheet (place card, Change,
  note, Save, Delete), a place search sheet with a custom-stop fallback, edit mode (reorder, delete,
  rename day, remove day), a days list reached from Home's owner-only "Edit days" row, and the
  save-failed banner with Retry. Members see none of it.
- **Stops are real places by default.** A picked place's details (name, `place_id`, category,
  neighbourhood, address, opening hours, photo reference) are saved on the stop, so viewing a plan
  never searches. A custom stop is free text with an empty `place_id` and is labelled as custom.
  Stops stored before these fields existed still load.
- **Place search sits behind `PlaceSearchService`** and is backed by `MockPlaceSearchService`
  (bundled place data, no network). The app never calls Google Places; the backend implementation
  replaces the mock where it is provided in `lib/main.dart`.
- **Change record** — every stop carries `last_change` (added / edited) and every day carries
  `last_change` (added / renamed / stop removed / stops reordered) with the author (a person's uid,
  or Scout) and a client timestamp. Nothing displays it yet.

## Remaining work

1. **Editable generated plan before creation** (FEAT-007 follow-up) — reuse the stop/day
   editor against the in-memory draft in the create flow so tweaks are seeded via
   `seedItinerary(dailyPlans:)`; editing the review must not trigger regeneration. The create
   flow is being replaced, so design this against the new flow, not
   `create_trip_review_steps.dart`.
2. **Real place search** — implement `PlaceSearchService` against our backend and swap it in for
   the mock. Photo references cannot be shown until that source exists; stops show a placeholder.
3. **`place_id` enrichment** (optional, own PR) — generated stops and stops stored before stage 1
   have no saved place details; resolve them through the backend place search and tolerate missing
   details until then.
4. **Full change history** — the record is the latest change per stop and per day, kept inside
   `daily_plans`. Who removed a day is not recorded (the day is gone), and there is no history to
   undo from. Both need a top-level change log, which means a Firestore rule change and deploy.
5. **Reorder days** — optional; not in stage 1.

## Open questions

- None. Last-write-wins stays when FEAT-024 adds admins as co-editors (decided 2026-11-22);
  each change records who made it and when, without showing it in the app yet.

## Notes / history

- 2025-06-22: Created
- 2026-11-17: Resolved the data-shape and conflict questions, recorded the owner-only editing
  model shipped in #107 (completion toggle), and added the remaining CRUD plan.
- 2026-11-22: Editing will widen to owner and admins only (FEAT-024), not to every member.
- 2026-11-21: Stage 1 of the trip roles rollout shipped owner editing (CRUD, edit UI, saved place
  details, mock place search, change record). Steps 1 and 2 of the previous plan are done.
