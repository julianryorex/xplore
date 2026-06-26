# FEAT-048: Personal Travel Profile & Stats ("Passport")

| Field | Value |
|-------|-------|
| **ID** | FEAT-048 |
| **Priority** | P4 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Owner** | — |
| **Effort** | M |

> Strong retention/identity candidate — could be promoted to P3 if between-trips engagement becomes a focus.

## Problem

Once a trip ends, there's little reason to return to Xplore, and the profile is thin (name + avatar). Travelers love seeing their own footprint, and that identity layer is missing — which also means trip creation (FEAT-007) can't personalize from a user's history.

## Proposed solution

A personal **travel profile / "passport"**: stats like countries and cities visited, number of trips, distance traveled, and a map of where you've been (a la Polarsteps "Travel DNA"). Derived from the user's trip history. Doubles as the source of pre-filled preferences for FEAT-007 trip creation, and is a natural Xplore Plus flex (richer stats / shareable card).

## User stories

- As a user, I want to see countries/cities I've visited, so the app reflects my travel identity.
- As a returning user, I want a reason to open Xplore between trips, so it stays part of my life.
- As a planner, I want trip creation to know my style from past trips, so it starts personalized.

## Acceptance criteria

- [ ] Aggregate stats from trip history: countries, cities, trip count, distance, a "places I've been" map
- [ ] Profile screen surfaces stats (extends current profile)
- [ ] Derived "travel preferences" available to FEAT-007 trip creation as defaults
- [ ] Solo and group trips both contribute

## Success metrics

- Between-trip (no active trip) opens vs. baseline
- Trip-creation flows that use pre-filled preferences

## Dependencies

- FEAT-002 (trips/history), FEAT-015 (profile cloud sync). Feeds FEAT-007 (trip creation). Optional Plus gating (FEAT-020)

## Related code

- `lib/features/profile/`, `lib/screens/profile_page.dart`, `lib/features/trip/` (history source)

## Open questions

- Map of visited places: derive from itinerary stops, arrivals (FEAT-047), or explicit check-ins?
- Which stats are free vs. Plus?
- Shareable "year in travel" card (acquisition loop)?

## Notes / history

- 2026-06-26: Created. From the UX gap review — identity + between-trips retention; also a personalization source for trip creation.
