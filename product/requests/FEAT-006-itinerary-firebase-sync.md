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
- As an organizer adjusting a plan Scout drafted, I want to swap a stop for another real place,
  so the stop keeps its map pin, hours and directions.
- As an organizer, I want to add something that is not a place ("back to the hotel lobby"),
  so the plan can hold the whole day.
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
2. **Edit UI, place-first** — design the editor for a plan the agent drafted and a person
   adjusts, not for a plan typed from nothing:
   - **Entry points.** Tapping a stop keeps opening its detail page, which everyone can read;
     the owner gets an Edit button there that opens the stop editor. Home's Itinerary card
     gets an owner-only "Edit days" row that opens the days list.
   - **Add a stop opens place search.** Picking a result stores that place's `place_id` and
     name. "Add as a custom stop" is the secondary option for things that are not places.
   - **A real-place stop shows a place card** (name, category, address, hours). Its name is
     not free text: change the stop by choosing another place or by making it a custom stop.
     The note is editable.
   - **A custom stop** has a free-text name and note and an empty `place_id`. It is marked as
     custom wherever stops are listed and has no map pin, hours or directions.
   - Edit mode on the day for reorder, delete, rename day and remove day; a days list for
     add, rename and remove. Deletes go through the shared confirmation dialog.
   - Show `saveError` with a retry; the unsaved stop stays visible, marked as not saved.
   - No Scout labelling in stage 1 ("Drafted by Scout", "Written by Scout", "Plan day" on the
     day page): Scout is not shipped, so nothing has an agent author yet.
   - An empty day is an edge case (a day the owner just added, or generation failed), not the
     default view of a new trip.
   - Gate everything on `canEdit` so members and goldens keep the read-only view. Closes #40
     together with step 1.
   - Designs: https://claude.ai/artifact/JpjPa1wEPNsurcpghrpV2r (private canvas).
3. **Editable generated plan before creation** (FEAT-007 follow-up) — reuse the stop/day
   editor against the in-memory draft in the create flow so tweaks are seeded via
   `seedItinerary(dailyPlans:)`; editing the review must not trigger regeneration. The create
   flow is being replaced, so design this against the new flow, not
   `create_trip_review_steps.dart`.
4. **Place search behind our backend, mocked for now** (required by step 2) — the app never
   calls Google Places directly; place search and place details go through our own backend.
   Until that backend exists, stage 1 runs on mock place data behind the same interface, so
   swapping in the real source later touches one place.
   **Save the place details on the stop** when it is picked — name, `place_id`, category,
   neighbourhood, address, opening hours and a photo reference — so viewing a plan does not
   call the place source again. Saved hours can go stale; refreshing them is a later concern.
   Lazy lookup of a `place_id` from a typed name is dropped: it can silently pick the wrong
   place. Stops that predate this keep an empty `place_id` and read as custom stops.
5. **Record the author of each change** — every add, edit, delete and reorder stores who made
   it and when. The author can be a person or Scout, so an agent-written stop can later be
   told apart from one a person changed. Nothing is displayed yet (FEAT-024).

## Open questions

- None. Last-write-wins stays when FEAT-024 adds admins as co-editors (decided 2026-11-22);
  each change records who made it and when, without showing it in the app yet.

## Notes / history

- 2025-06-22: Created
- 2026-11-17: Resolved the data-shape and conflict questions, recorded the owner-only editing
  model shipped in #107 (completion toggle), and added the remaining CRUD plan.
- 2026-11-22: Editing will widen to owner and admins only (FEAT-024), not to every member.
- 2026-11-22: Edit UI made place-first. The working assumption is that Scout drafts the plan
  and a person edits it, so stops are real places with a `place_id` by default and custom
  stops are the fallback. Real place search moved from optional to required.
- 2026-11-22: Place search goes through our backend, mocked for stage 1; place details are
  saved on the stop; Scout labels are hidden until Scout ships. Entry points settled: Edit
  on the stop detail page, and an "Edit days" row on Home.
