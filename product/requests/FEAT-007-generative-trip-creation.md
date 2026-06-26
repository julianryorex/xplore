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

Replace the sheet with a full-screen, onboarding-style flow ("buckets") that
ends in a generated itinerary. Ordered broad-commitment → fine-detail:

1. **Destination** — single city (phase 1); anchors cover, map center, generation.
2. **Dates & duration** — exact range OR flexible "~N days"; duration drives length.
3. **Who's coming** — solo/couple/friends/family + size as a *generation signal*, not an invite gate.
4. **Vibe & preferences** — interests + pace + budget + free-text "ideal trip".
5. **Generate + review** — deterministic day skeleton (phase 1); Gemini (phase 2). Read-only review.
6. **Finishing touches** — name + cover, auto-suggested from destination.
7. **Invite your crew** — FEAT-003 share link, genuinely skippable.

**Design principle — solo is first-class.** No group gate, invite is skippable,
generation works with no group signal, and Home never nags a solo trip to
invite people. Copy adapts so a solo user is never told they're missing people.

**Extensibility principle.** The flow is an *ordered list of steps*
(`CreateTripStep` enum + `TripCreationCubit.steps`), each a self-contained widget
reading/writing a slice of a single flat `TripDraft`. Adding, reordering, or
splitting a bucket is a change to the list, not a rewrite.

### Phase 1 — flow + deterministic skeleton (no AI) — shipped in this PR

- `lib/features/trip/models/trip_draft.dart` — flat `TripDraft` + enums.
- `lib/features/trip/bloc/trip_creation_cubit.dart` + `trip_creation_state.dart`.
- `lib/features/trip/presentation/create_trip/` — flow page + 7 step bodies.
- `DeterministicItineraryGenerator` — one `DailyPlanModel` per day, titled
  "Day N", anchored to the destination, empty stops.
- `TripCubit.createTripFromDraft(draft, itinerary:)` persists destination /
  dates / `TripPreferences` and seeds the skeleton via
  `ItineraryService.seedItinerary(..., dailyPlans:)` (idempotency preserved).
- `TripModel` gains `destination` + `preferences`; `/create-trip` route.

### Phase 2 — Gemini engine (absorbs FEAT-010) — shipped in this PR

- `GeminiItineraryService implements ItineraryGenerator`: builds a structured
  prompt from `TripDraft`, calls Gemini with `GEMINI_API_KEY`, parses/validates
  JSON, and **falls back to the deterministic skeleton** on missing key /
  network / malformed / empty output. Swapped in via the `ItineraryGenerator`
  provider behind the same "Generate" UI.
- Regenerations should later be gated behind FEAT-021 credits.

## User stories

- As a traveller, I want to go from a destination to a day-by-day plan in a few
  taps, so that starting a trip feels effortless.
- As a solo traveller, I want to plan without being pushed to invite anyone, so
  the app feels built for me too.
- As an organizer, I want a named, populated trip before I share an invite, so
  the people I invite see something real.

## Acceptance criteria

- [x] Multi-step flow replaces the single-field create sheet.
- [x] Flow is driven by an ordered step list over a single `TripDraft`.
- [x] "Generate" produces a day skeleton that seeds the itinerary (no more empty seed).
- [x] Solo is a no-gate default; invite (bucket 7) is skippable.
- [x] New `TripModel` fields (destination, preferences, dates) persist on create.
- [x] Gemini engine behind the same UI with deterministic fallback.
- [ ] Generated stops resolve real Google `place_id`s (deferred — see open questions).
- [ ] Editable/regenerated review (deferred to itinerary CRUD, FEAT-006/FEAT-024).

## Success metrics

- % of created trips that reach the "Generate" step.
- % of trips created with a non-empty itinerary (target: ~100% vs ~0% today).
- Solo vs group trip creation completion rates (should be comparable).

## Dependencies

- FEAT-003 invites (share link, shipped) — reused in bucket 7.
- FEAT-021 credits — later gate for AI regeneration.
- Absorbs FEAT-010 (wire Gemini into UI) and resolves FEAT-006 "A2" (content seed).

## Related code

- `lib/features/trip/presentation/create_trip/*` — flow + step bodies
- `lib/features/trip/bloc/trip_creation_cubit.dart` / `trip_creation_state.dart`
- `lib/features/trip/models/trip_draft.dart` / `trip_preferences.dart` / `trip_model.dart`
- `lib/features/trip/services/itinerary_generator.dart` / `gemini_itinerary_service.dart`
- `lib/features/trip/bloc/trip_cubit.dart` — `createTripFromDraft`
- `lib/features/itinerary/services/itinerary_service.dart` — `seedItinerary(dailyPlans:)`

## Open questions

- **`place_id` strategy.** `LocationPlanModel.placeId` is required/non-null and
  feeds map/detail screens. Gemini can't invent valid Google ids. Phase 1+2 use
  empty `place_id`; resolve lazily via Places (cost/latency) or per-stop lookup.
- Extra preference candidates to consider when buckets split: dietary,
  accessibility, season/month, transport mode, accommodation area, energy/
  wake-time, must-sees.
- Multi-city destinations (phase 1 is single city).
- Cover image is a gradient placeholder; real cover selection is deferred.

## Notes / history

- 2026-06-26: Created; phase 1 + 2 implemented on `feat/trip-creation-dev-home`.
  Bucket order locked with product; competitor research (Wanderlog, Mindtrip,
  Layla, Troupe, Polarsteps, iPlan.ai, Wonderplan) validated the shape and the
  solo-first stance.
