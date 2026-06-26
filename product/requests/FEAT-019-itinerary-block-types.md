# FEAT-019: Richer Itinerary Block Types

| Field | Value |
|-------|-------|
| **ID** | FEAT-019 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | enabler |
| **Effort** | L |
| **Owner** | — |

## Problem

The itinerary model is place-only: `LocationPlanModel` has `name`, `place_id`, `completed`, `description`. Real itineraries also contain **flights, lodging check-in/out, transit legs, reservations, free time, and notes**. There's no way to represent "9:00 flight to Osaka" or "check into the ryokan", which quietly caps the realism of generated plans (FEAT-010), the value of integrations (FEAT-037), and the usefulness of a Today view (FEAT-018).

## Proposed solution

Generalize itinerary items into **typed blocks** sharing a common base (id, title, optional time/time-window, optional `place_id`, notes, completed), with variants such as `place`, `flight`, `lodging`, `transit`, `reservation`, `note`, `free_time`. The UI renders per type (icons, layout, actions), generation and integrations emit typed blocks, and the Today view orders the day by time. Requires a Firestore schema evolution with backward-compatible parsing/migration of existing `daily_plans`.

## User stories

- As an organizer, I want to add a flight or hotel block, so the itinerary reflects the real day.
- As a traveler, I want time-stamped blocks, so "now/next" is accurate.
- As the AI (FEAT-010), I want a typed schema to emit, so plans include logistics, not just sights.

## Acceptance criteria

- [ ] Typed block model (Freezed) with shared base + variants; `fromJson` tolerant of legacy place-only entries
- [ ] Migration/compat path for existing `itineraries/{tripId}.daily_plans`
- [ ] Per-type rendering in itinerary card / focus / overview
- [ ] Optional time / time-window field used for ordering
- [ ] `make gen` codegen updated; tests for parsing legacy + new shapes

## Success metrics

- % of itinerary items that are non-place types after launch
- Generated plans (FEAT-010) include logistics blocks

## Dependencies

- FEAT-006 (data layer). Enables/strengthens FEAT-010, FEAT-018, FEAT-037, FEAT-031, FEAT-040

## Related code

- `lib/features/itinerary/models/itinerary_models.dart` (`DailyPlanModel`, `LocationPlanModel`, `PlanModel`)
- `lib/features/itinerary/services/itinerary_service.dart`, `lib/features/itinerary/widgets/itinerary_card.dart`
- `lib/screens/itinerary_focus_page.dart`, `itinerary_overview_page.dart`

## Open questions

- Flat typed list per day vs. keeping morning/afternoon/evening grouping?
- How strict are times (exact vs. fuzzy ordering)?
- Coordinate the schema change with the FEAT-010 generation contract to avoid double migration.

## Notes / history

- 2026-06-26: Created. Structural enabler surfaced during the in-trip UX review; foundational for realistic generation + logistics.
