# FEAT-003: Trip Invites & Join Flow

| Field | Value |
|-------|-------|
| **ID** | FEAT-003 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |

## Problem

`ItineraryModel.invitees` exists in the data model but there is no UI or backend flow to invite friends. Group travel requires ≥2 people on the same trip context — the primary viral loop.

## Proposed solution

Generate **invite links** (Firebase Dynamic Links or universal links) with trip ID + optional invite token. Join flow: deep link → auth (FEAT-001) → add user to trip members → load trip context. In-app share sheet from trip settings.

## User stories

- As an organizer, I want to share an invite link in iMessage, so friends can join without manual setup.
- As an invitee, I want to tap a link and land in the trip, so I'm on the map with everyone else.
- As the product, we track invites sent vs. accepted for growth metrics.

## Acceptance criteria

- [ ] Invite link generation per trip
- [ ] Deep link handling adds authenticated user to `trip.members`
- [ ] Join confirmation screen (trip name, member avatars)
- [ ] Handle invalid/expired/revoked invites gracefully
- [ ] Member cap enforced per tier (6 free, 20 Plus — see MONETIZATION.md)

## Success metrics

- Invite acceptance rate > 40%
- Median trip size ≥ 3 members for active trips

## Dependencies

- FEAT-001, FEAT-002

## Related code

- `lib/features/itinerary/models/itinerary_models.dart` — `invitees` field
- `lib/routes.dart` — add join route / deep link handler
- iOS: Associated Domains for universal links

## Open questions

- Require organizer approval for join vs. open link?
- QR code for in-person join at airport?

## Notes / history

- 2025-06-22: Created
