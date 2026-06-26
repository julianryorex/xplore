# FEAT-047: Destination Arrival Moments

| Field | Value |
|-------|-------|
| **ID** | FEAT-047 |
| **Priority** | P4 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Multi-city/country trips (e.g. a Japan tour through Tokyo, Osaka, Kyoto) have natural milestone moments — *arriving in a new city* — that the app currently does nothing with. During the trip itself Xplore is mostly passive; there's no delightful, in-the-moment feedback that makes it feel alive. Marking arrivals is a low-effort, high-delight way to boost in-trip engagement and re-opens, and it reinforces the "remember together" pillar.

## Proposed solution

Detect when a member enters a **planned destination's area** (city/region level, derived from the trip's itinerary) during trip dates, and celebrate it:

- **App backgrounded:** a push notification — "Welcome to Kyoto!" (optionally social: "Julian just arrived in Osaka" to other trip members).
- **App open / foreground:** a dedicated, tasteful **arrival screen** — hero moment for the city, what's planned there, a CTA into the day, optional "mark the moment" tie-in to the gallery.

Designed to be **delightful, not noisy:** one arrival moment per destination per arrival, with a cooldown/debounce and a user setting to tone it down or off. This is the city-level sibling of FEAT-044 (stop proximity nudges) and should share the underlying geofence engine.

## User stories

- As a traveler on a multi-city tour, I want a moment when I arrive in each city, so the app feels interactive and the trip feels marked.
- As a trip member, I want to know when a friend arrives in the next city, so the group stays in sync (optional/social).
- As a user who dislikes noise, I want arrival moments to be tasteful and adjustable, so it never feels like spam.

## Acceptance criteria

- [ ] Derive city/region geofences from the itinerary destinations (geocode `DailyPlanModel.location` / trip destination to center + radius)
- [ ] Background arrival → push notification (FEAT-012) with deep link into the destination's day
- [ ] Foreground arrival → dedicated celebratory arrival screen (reuse `FadeThroughPageRoute`)
- [ ] One moment per destination per arrival; cooldown/debounce; no repeats on GPS jitter
- [ ] User setting to reduce frequency or disable arrival moments
- [ ] Only fires within trip dates / for an active trip

## Success metrics

- App opens triggered by arrival notifications (CTR)
- In-trip session frequency vs. cohort without arrival moments
- Opt-out rate stays low (noise check)

## Dependencies

- **FEAT-013** (background location) — required for background arrival detection
- **FEAT-012** (push notifications) — required for the notification path
- **FEAT-006 / FEAT-002** — itinerary destinations to geofence; needs multi-destination trip data (current model has a single per-day `location` string; multi-city geofencing needs geocoded city centers)
- Sibling: **FEAT-044** (stop-level proximity nudges) — share the geofence engine

## Related code

- `lib/features/location/bloc/location_cubit.dart` — position stream / background updates
- `lib/features/map/bloc/map_cubit.dart` — geofence/neighborhood TODOs
- `lib/features/itinerary/models/itinerary_models.dart` — `DailyPlanModel.location` (geocode source)
- `lib/routes.dart` — new arrival screen route (`FadeThroughPageRoute`)

## Open questions

- City center + radius: geocode itinerary locations, or capture explicit destinations during trip creation (FEAT-007)?
- How social should arrivals be by default (self-only vs. notify trip members)?
- Should an arrival auto-advance the "active day" / map focus to the new city?
- Tie arrival to a gallery/memory prompt, or keep it a lightweight moment?

## Notes / history

- 2026-06-26: Created. From an interactivity brainstorm — city-level arrival moments for multi-city tours, distinct from FEAT-044's stop-level proximity. Explicitly scoped to stay tasteful ("interactive and fun without being too much").
