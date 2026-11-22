# FEAT-026: Referral / Invite Rewards

| Field | Value |
|-------|-------|
| **ID** | FEAT-026 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | M |
| **Owner** | — |

## Problem

Invites (FEAT-003) drive growth but offer no incentive to share beyond social utility.

## Proposed solution

Reward organizers: e.g. a free Trip Pass for the organizer's next trip once a trip reaches 6+ joined members, or a month of Plus when an invited guest organizes their own first trip. There are no AI credits to grant (see FEAT-020). Track referral attribution on invite links.

## Acceptance criteria

- [ ] Invite links carry referrer UID
- [ ] Reward granted on first trip join by new user
- [ ] Fraud limits (same device, duplicate accounts)

## Dependencies

- FEAT-003, FEAT-020, FEAT-025

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
