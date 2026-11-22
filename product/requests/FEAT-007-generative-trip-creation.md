# FEAT-007: Generative trip creation flow

| Field | Value |
|-------|-------|
| **ID** | FEAT-007 |
| **Priority** | P0 |
| **Status** | `in_progress` |
| **Revenue impact** | retention / enabler |
| **Effort** | L |
| **Owner** | — |

## Problem

Creating a trip is a single-field "name it" bottom sheet (`_CreateTripSheet` in
`home_page.dart`). It throws away the rich `TripModel` shape (dates, cover,
destination) and seeds an **empty** itinerary, so a brand-new trip has nothing
in it. There's no on-ramp from "I want to go somewhere" to "here's a plan",
which is the core promise of an AI travel app and the moment competitors
(Wanderlog, Mindtrip, Layla) win users.

## Proposed solution

Replace the sheet with a full-screen, step-by-step flow that supports **multiple
places per trip** (e.g. Tokyo, Hakone, Kyoto, Osaka; up to 8) and ends in a
trip plus an invite screen:

1. **Where** — a real Google map with numbered pins and a route line fitted to
   the places; add places via search over a **hardcoded place catalog**, reorder,
   swipe to remove with undo.
2. **When** — exact dates OR a flexible number of nights; nights are allocated per place.
3. **Who and vibe** — group, group size (a *planning signal*, not an invite gate),
   interests, pace, free-text notes. Skippable.
4. **Plan** — a preview built by a hardcoded stub (`buildStubPlan`) and an editable
   trip name. "Create trip" writes the trip with a `stops` list.
5. **Invite** — FEAT-003 share link, genuinely skippable.

**Real itinerary generation is deferred.** The in-app Gemini "Generate" step is
no longer wired into the flow; agentic generation is being built in a separate
repo. `ItineraryGenerator` / `GeminiItineraryService` still exist in `lib/` but
are unused. What the Plan step shows and seeds is a stub: one `DailyPlanModel`
per day with a title from the place's hardcoded day themes, no stops.

**Design principle — solo is first-class.** No group gate, invite is skippable,
and Home never nags a solo trip to invite people. Copy adapts so a solo user is
never told they're missing people.

**Extensibility principle.** The flow is an *ordered list of steps*
(`CreateTripStep` enum + `TripCreationState.steps`), each a self-contained widget
reading/writing a slice of a single flat `TripDraft`. Adding, reordering, or
splitting a step is a change to the list, not a rewrite.

### Shipped

- `lib/features/trip/models/trip_draft.dart` — flat `TripDraft` + enums;
  `trip_stop.dart` (`TripStop`), `nights_allocation.dart`, `trip_plan.dart`.
- `lib/features/trip/bloc/trip_creation_cubit.dart` + `trip_creation_state.dart`.
- `lib/features/trip/presentation/create_trip/` — flow page, step bodies, route map, place search sheet.
- `lib/features/trip/services/stub_plan_builder.dart` — the stub plan (no network, no AI).
- `TripCubit.createTripFromDraft(draft, itinerary:)` persists stops / destination /
  dates / `TripPreferences` and seeds the stub skeleton via
  `ItineraryService.seedItinerary(..., dailyPlans:)` (best-effort, idempotency preserved).
- `TripModel` gains `destination`, `preferences` and `stops`; `/create-trip` route.

### Deferred — real generation

Gemini / agentic generation into the created trip is not part of this flow. No
decision has been made on how it will be wired back in.

## User stories

- As a traveller, I want to go from a set of places to a trip with dates and a
  day-by-day outline in a few taps, so that starting a trip feels effortless.
- As a solo traveller, I want to plan without being pushed to invite anyone, so
  the app feels built for me too.
- As an organizer, I want a named trip with its places and dates before I share an
  invite, so the people I invite see something real.

## Acceptance criteria

- [x] Multi-step flow replaces the single-field create sheet.
- [x] Flow is driven by an ordered step list over a single `TripDraft`.
- [x] The Plan step builds a **stub** day skeleton that seeds the itinerary (no more empty seed); days have titles but no stops.
- [x] Solo is a no-gate default; the invite screen is skippable.
- [x] New `TripModel` fields (destination, preferences, dates, `stops`) persist on create.
- [x] A trip can have multiple places (1–8), ordered, with nights per place.
- [ ] Real itinerary generation (Gemini / agentic) in the flow — **not wired; deferred** (built in a separate repo).
- [ ] Places come from Google Places instead of the hardcoded catalog; generated stops resolve real Google `place_id`s (deferred — see open questions).
- [ ] Editable/regenerated review (deferred to itinerary CRUD, FEAT-006/FEAT-024).

## Success metrics

- % of created trips that reach the Plan step.
- % of trips created with a seeded day skeleton (target: ~100% vs ~0% before this flow).
- Solo vs group trip creation completion rates (should be comparable).

## Dependencies

- FEAT-003 invites (share link, shipped) — reused on the invite screen.
- FEAT-020 plans — gate for Scout planning beyond the free planned day.
- Phase 2 wires in Scout (FEAT-037), which replaces the retired Gemini spec; only stubs FEAT-006 "A2" (content seed).

## Related code

- `lib/features/trip/presentation/create_trip/*` — flow + step bodies
- `lib/features/trip/bloc/trip_creation_cubit.dart` / `trip_creation_state.dart`
- `lib/features/trip/models/trip_draft.dart` / `trip_preferences.dart` / `trip_model.dart`
- `lib/features/trip/services/stub_plan_builder.dart` — the plan the flow uses
- `lib/features/trip/services/itinerary_generator.dart` / `gemini_itinerary_service.dart` — exist but are not wired into the flow
- `lib/features/trip/bloc/trip_cubit.dart` — `createTripFromDraft`
- `lib/features/itinerary/services/itinerary_service.dart` — `seedItinerary(dailyPlans:)`

## Open questions

- **`place_id` strategy.** `LocationPlanModel.placeId` is required/non-null and
  feeds map/detail screens. The stub plan has no stops, so none are needed yet;
  if generation returns, ids must be resolved via Places (cost/latency) or per-stop lookup.
- Extra preference candidates to consider when steps split: dietary,
  accessibility, season/month, transport mode, accommodation area, energy/
  wake-time, must-sees.
- Place search is over a hardcoded catalog; whether to move to Google Places is undecided.
- Cover image is a gradient placeholder; real cover selection is deferred.

## Notes / history

- 2026-06-26: Created; phase 1 + 2 implemented on `feat/trip-creation-dev-home`.
  Bucket order locked with product; competitor research (Wanderlog, Mindtrip,
  Layla, Troupe, Polarsteps, iPlan.ai, Wonderplan) validated the shape and the
  solo-first stance.
- 2026-11-18: Docs updated to match PR #227: flow rebuilt as four steps plus invite,
  multi-place (up to 8); in-app Gemini generation removed from the flow (deferred,
  being built in a separate repo); Plan step uses a hardcoded stub.
- 2026-11-22: The Gemini UI and AI credits specs were retired; generation now points at Scout (FEAT-037) and plan gating (FEAT-020).
