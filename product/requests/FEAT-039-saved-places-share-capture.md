# FEAT-039: Saved Places & Wishlist + Share-In Capture

| Field | Value |
|-------|-------|
| **ID** | FEAT-039 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | M |
| **Owner** | — |

## Problem

Xplore gives users no reason to open the app when they're *not* actively planning or on a trip, and no way to capture inspiration in the moment ("save this place for a future trip"). Today, a place someone finds on Google Maps or an Instagram reel has nowhere to go. That's a missed retention and acquisition loop.

## Proposed solution

A personal **saved places / wishlist** (places and destinations a user wants to visit), plus an **iOS Share Extension** so a Google Maps link, web page, or social link can be shared *into* Xplore and turned into a saved place — or dropped directly onto a trip as a stop. This is the "Start Anywhere" inbound pattern (Mindtrip) and keeps users engaged between trips.

## User stories

- As a user, I want to save a place I stumble on, so I remember it for a future trip.
- As a planner, I want to share a Maps/Instagram link into Xplore, so capturing inspiration is one tap.
- As an organizer, I want to move a saved place onto a trip's itinerary, so the wishlist feeds real plans.

## Acceptance criteria

- [ ] Personal saved-places/wishlist store (Firestore under user), with optional destination tags
- [ ] iOS Share Extension accepting a URL/text → resolves to a place (Google Places) → saves
- [ ] "Add to trip" action moving a saved place to an active trip's itinerary (ties to FEAT-019 blocks)
- [ ] Browse/manage saved places UI

## Success metrics

- Saved places created per user; between-trip (no active trip) opens
- Share-extension captures → conversion to trip stops

## Dependencies

- FEAT-002, FEAT-006; iOS Share Extension (native target); Google Places for resolution (overlaps FEAT-037)

## Related code

- iOS share extension target (new), `lib/features/itinerary/` (add-to-trip), Places resolution

## Open questions

- Saved places personal-only vs. shareable with a trip/group?
- How much metadata to resolve at capture time vs. lazily?

## Notes / history

- 2026-06-26: Created. From the UX gap review — between-trips retention + inbound inspiration capture.
