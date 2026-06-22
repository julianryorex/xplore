# FEAT-002: Trip Entity & Multi-Trip Management

| Field | Value |
|-------|-------|
| **ID** | FEAT-002 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |

## Problem

The app loads one demo itinerary keyed `ph4kd`. Users cannot create a trip, switch trips, or see past/upcoming adventures. Multi-trip is required for repeat usage and subscription value ("unlimited trips" in Plus tier).

## Proposed solution

Introduce a **Trip** domain model and `TripCubit` as the session context for the app: active trip ID, metadata (name, dates, cover image), member list. Home screen shows trip switcher or trip list. Persist trips in Firebase RTDB or Firestore under `/users/{uid}/trips` and `/trips/{tripId}`.

## User stories

- As an organizer, I want to create a new trip with a name and dates, so that my group has a dedicated space.
- As a user on multiple trips, I want to switch active trips, so that I see the right plan and map.
- As a free-tier user, I want one active trip at a time (enforced in FEAT-020).

## Acceptance criteria

- [ ] `TripModel` (Freezed) with id, title, start/end dates, memberIds, createdBy
- [ ] Create trip flow from home (replace disabled "See all" or add CTA)
- [ ] Active trip ID available app-wide (replaces `itineraryId` constant)
- [ ] Trip list / switcher UI
- [ ] Empty state when user has no trips

## Success metrics

- Avg trips per MAU > 1.2 within 90 days of launch
- Trip creation funnel completion > 60%

## Dependencies

- FEAT-001 (auth) for ownership and membership

## Related code

- `lib/constants/constants.dart` — `itineraryId`
- `lib/features/itinerary/bloc/itinerary_cubit.dart` — loads single demo trip
- `lib/features/itinerary/models/itinerary_models.dart` — `ItineraryModel.id`, `invitees`
- `lib/screens/home_page.dart` — "See all" button is disabled

## Open questions

- Firestore vs. RTDB for trip documents? (Itinerary nested structure may favor Firestore)
- One itinerary doc per trip or embed daily plans in trip doc?

## Notes / history

- 2025-06-22: Created
