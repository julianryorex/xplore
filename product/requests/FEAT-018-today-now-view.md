# FEAT-018: In-Trip "Today" / Now View

| Field | Value |
|-------|-------|
| **ID** | FEAT-018 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

The whole app is planning-oriented: the itinerary is a set of day *cards* you browse. During the trip itself there's no real-time "what's happening now / next" surface, so the app goes quiet exactly when the user is living the trip. The most engaging in-trip moment — "where am I supposed to be right now, and what's next?" — doesn't exist.

## Proposed solution

A **Today / Now** view that auto-selects the active day (by date, and later by location) and surfaces the present moment: current stop, next stop with ETA/distance, time-of-day awareness, and quick actions (view on map, directions, mark done). It's a new *lens* over existing itinerary data, not new infrastructure. Pairs naturally with FEAT-047 (arrival moments) and FEAT-013 (live location).

## User stories

- As a traveler mid-trip, I want a glanceable "now and next" view, so I don't scrub through day cards.
- As a member, I want the day to auto-advance to today, so the app is useful without fiddling.
- As a user, I want quick directions to my next stop, so the plan is actionable in the moment.

## Acceptance criteria

- [ ] Auto-select the active day from the current date within trip dates
- [ ] Show current stop + next stop with relative timing and distance/ETA
- [ ] Quick actions: focus on map, get directions (ties to FEAT-040), mark stop done (ties to FEAT-016)
- [ ] Graceful states: before trip ("starts in N days"), between days, after trip
- [ ] Entry point from Home / nav for an active trip

## Success metrics

- In-trip (within trip dates) session frequency vs. baseline
- Taps on "directions"/"next stop" actions per active-trip day

## Dependencies

- FEAT-006 (itinerary data), FEAT-002 (active trip)
- Complements FEAT-047 (arrival moments), FEAT-013 (location), FEAT-016 (completion), FEAT-040 (directions)

## Related code

- `lib/features/itinerary/bloc/itinerary_cubit.dart`, `itinerary_models.dart` (`DailyPlanModel`)
- `lib/screens/home_page.dart` (entry/section), `lib/features/map/` (focus)

## Open questions

- Its own tab, a Home section, or a top-of-itinerary mode?
- Time-of-day ordering depends on FEAT-019 typed blocks / times — how much to infer without explicit times?

## Notes / history

- 2026-06-26: Created. From the in-trip UX gap review — the app plans trips well but does little while you're *on* one.
