# FEAT-031: Activity Booking Affiliate Links

| Field | Value |
|-------|-------|
| **ID** | FEAT-031 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | direct |
| **Effort** | M |
| **Owner** | — |

## Problem

Itinerary stops have names and `place_id` but no booking action — missed affiliate revenue at high-intent moments.

## Proposed solution

"Book / Reserve" on `ItineraryFocusPage` lets the group book from the stop itself: a table for eight, six tour tickets or a transfer, through a partner (GetYourGuide, Viator, OpenTable). The partner pays Xplore a commission and the confirmation lands in the trip wallet (FEAT-037).

**Commission never decides the plan.** Scout chooses stops first and a booking link is attached afterwards; partners cannot pay to appear. Bookable stops are labeled.

## Acceptance criteria

- [ ] CTA on location detail when partner match exists
- [ ] Opens in-app browser or SFSafariViewController
- [ ] Bookable stops labeled; affiliate disclosure copy approved
- [ ] Group size pre-filled from trip membership
- [ ] Stop selection and ranking has no access to partner or commission data
- [ ] Booking confirmation saved to the trip wallet

## Dependencies

- FEAT-006, partner agreements

## Related code

- `lib/screens/itinerary_focus_page.dart`
- `LocationPlanModel.placeId`

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
