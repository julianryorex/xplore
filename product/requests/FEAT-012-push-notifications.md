# FEAT-012: Push Notifications

| Field | Value |
|-------|-------|
| **ID** | FEAT-012 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Home header has a notifications icon that only logs to console. Users miss invite accepts, itinerary changes, and "friend arrived at hotel" moments — hurting re-engagement during trips.

## Proposed solution

Firebase Cloud Messaging + in-app notification center. MVP events: trip invite, itinerary updated, new gallery batch, optional daily plan reminder.

## User stories

- As a member, I want a push when the plan changes, so I'm not the one person who didn't know.
- As an organizer, I want to know when someone accepts my invite.

## Acceptance criteria

- [ ] FCM token registration per user
- [ ] Notification preferences screen (linked from header icon)
- [ ] Deep link from notification to relevant screen
- [ ] iOS permission flow integrated in onboarding (FEAT-005)
- [ ] **Itinerary-change push:** whenever a trip's itinerary is updated/changed (a day or
      stop added, edited, removed, or checked off — the FEAT-006 write path), send a push to
      the trip's *other* members (never the editor) **only if that recipient has itinerary
      notifications enabled** in their preferences. Triggered server-side (Cloud Function on
      the `itineraries/{tripId}` write) so it fires regardless of which client made the edit;
      respects the per-user opt-out and deep-links to the itinerary.

## Success metrics

- Push opt-in > 50%
- D7 retention +15% vs. no-push cohort (hypothesis)

## Dependencies

- FEAT-001, FEAT-002
- FEAT-006 (itinerary data layer / CRUD) — the itinerary-change push fans out off its
  `itineraries/{tripId}` write path.

## Related code

- `lib/screens/home_page.dart` — notifications button stub
- `lib/features/itinerary/services/itinerary_service.dart` — itinerary writes that should
  fan out a push (server-side trigger on the doc)

## Notes / history

- 2025-06-22: Created
- 2026-06-26: Made the "itinerary updated" event concrete — push other trip members on any
  itinerary change, gated on the recipient's per-user notification preference; fired
  server-side off the FEAT-006 write path.
