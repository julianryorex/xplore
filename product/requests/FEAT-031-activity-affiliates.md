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

"Book / Reserve" on `ItineraryFocusPage` deep links to partner (GetYourGuide, OpenTable) with affiliate params. Disclose affiliate relationship in UI.

## Acceptance criteria

- [ ] CTA on location detail when partner match exists
- [ ] Opens in-app browser or SFSafariViewController
- [ ] Affiliate disclosure copy approved

## Dependencies

- FEAT-006, partner agreements

## Related code

- `lib/screens/itinerary_focus_page.dart`
- `LocationPlanModel.placeId`

## Notes / history

- 2025-06-22: Created
