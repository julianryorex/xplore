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

## Success metrics

- Push opt-in > 50%
- D7 retention +15% vs. no-push cohort (hypothesis)

## Dependencies

- FEAT-001, FEAT-002

## Related code

- `lib/screens/home_page.dart` — notifications button stub

## Notes / history

- 2025-06-22: Created
