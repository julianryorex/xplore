# FEAT-003: Trip Invites & Join Flow

| Field | Value |
|-------|-------|
| **ID** | FEAT-003 |
| **Priority** | P0 |
| **Status** | `done` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |
| **Shipped** | PR #96 |

## Problem

`ItineraryModel.invitees` exists in the data model but there is no UI or backend flow to invite friends. Group travel requires ≥2 people on the same trip context — the primary viral loop.

## Proposed solution

Generate **invite links** (Firebase Dynamic Links or universal links) with trip ID + optional invite token. Join flow: deep link → auth (FEAT-001) → add user to trip members → load trip context. In-app share sheet from trip settings.

## User stories

- As an organizer, I want to share an invite link in iMessage, so friends can join without manual setup.
- As an invitee, I want to tap a link and land in the trip, so I'm on the map with everyone else.
- As the product, we track invites sent vs. accepted for growth metrics.

## Acceptance criteria

- [x] Invite link generation per trip (`TripService.createInvite` + `InviteLink.build`)
- [x] Deep link handling adds authenticated user to `trip.members` (`DeepLinkHandler` → `acceptInvite`)
- [x] Join confirmation screen (trip name, member avatars) (`join_trip_page.dart`)
- [x] Handle invalid/expired/revoked invites gracefully (`InviteLookup` / `_validateInvite`)
- [x] Member cap enforced per tier (6 free, 20 Plus — see MONETIZATION.md) (`validTripJoin` Firestore rule)
- [ ] **Production universal-link delivery** — host AASA + Associated Domains entitlement so tapped links open the app (deferred; tracked in GitHub #99)

## Success metrics

- Invite acceptance rate > 40%
- Median trip size ≥ 3 members for active trips

## Dependencies

- FEAT-001, FEAT-002

## Related code

- `lib/features/trip/services/trip_service.dart` — invite create / lookup / accept
- `lib/features/trip/services/invite_link.dart` — universal-link build/parse
- `lib/features/trip/services/deep_link_service.dart` — `app_links` wrapper
- `lib/features/trip/presentation/deep_link_handler.dart` — routes link → join after auth
- `lib/features/trip/presentation/join_trip_page.dart` — join confirmation screen
- `infra/rules/firestore.rules` — `validTripJoin` (self-add + member cap)
- `infra/hosting/` — staged AASA file + Cloudflare Worker (production enablement, #99)

## Open questions

- Require organizer approval for join vs. open link?
- QR code for in-person join at airport?
- ~~Production universal-link domain~~ — **resolved**: `xplore.olympuslabs.ai`
  (subdomain of the owned `olympuslabs.ai`; bundle id `com.olympuslabs.xplore`
  kept unchanged so the feature is fully reversible).

## Notes / history

- 2025-06-22: Created
- 2026-06-26: In-app invite/join flow shipped via PR #96 (link generation,
  deep-link routing through auth, join screen, invalid/expired/revoked handling,
  member-cap rule). Universal-link host set to `xplore.olympuslabs.ai`; iOS
  Associated Domains entitlement added and a Cloudflare Worker + AASA file staged
  under `infra/hosting/`. Production enablement (AASA hosting, App ID capability,
  DNS/Worker deploy) intentionally deferred until launch + >100 users — tracked
  in GitHub #99.
