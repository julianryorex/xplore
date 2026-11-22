# FEAT-020: Subscription / Xplore Plus Paywall

| Field | Value |
|-------|-------|
| **ID** | FEAT-020 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | direct |
| **Effort** | L |
| **Owner** | — |

## Problem

No billing infrastructure. Free tier limits in [MONETIZATION.md](../MONETIZATION.md) cannot be enforced without App Store subscriptions and server-side entitlement checks.

## Proposed solution

Integrate **RevenueCat** or native StoreKit 2: products for **Trip Pass** ($19.99 one-time per trip) and **Plus** ($4.99/mo or $29.99/yr). Guests never pay: one person buys and the upgrade covers everyone on the trip. Any member can buy a Trip Pass, and its benefits last until 30 days after the trip ends. Hosts pricing is covered by FEAT-045.

| | Free | Trip Pass | Plus |
|---|---|---|---|
| Trips | 1 active | The trip it was bought for | Unlimited |
| Travelers | Up to 6 | Up to 20 | Up to 20 per trip |
| Scout (FEAT-037) | One planned day | Unlimited for the trip | Unlimited |
| Photos (FEAT-022) | 500 MB | 10 GB | 10 GB per trip |
| Also | Plan, map, gallery, votes | Offline mode, expenses, trip wallet, disruption watch | Everything in Trip Pass |

There are no AI credits or credit packs; Scout usage is gated by plan only. Entitlements stored in Firebase custom claims or RevenueCat webhook → Firestore `users/{uid}/subscription`. Paywall surfaces: second trip creation, member cap, Scout beyond the free planned day, storage limit, offline mode, expenses.

## User stories

- As an organizer, I want to upgrade one trip for the whole group, so everyone gets Plus benefits.
- As a free user hitting limits, I want a clear upgrade path, not a cryptic error.

## Acceptance criteria

- [ ] App Store subscription products configured
- [ ] Restore purchases works
- [ ] Trip-level entitlement (Trip Pass, any member can buy, expires 30 days after trip end) and user-level entitlement (Plus, covers every trip the subscriber organizes)
- [ ] Limits enforced per the table above: trips, members, storage, Scout
- [ ] Paywall UI matches dark theme

## Success metrics

- Free → paid conversion 3–5% of trip organizers (hypothesis)
- MRR tracked in analytics

## Dependencies

- FEAT-001, FEAT-002, FEAT-024, FEAT-025

## Related code

- New: `lib/features/billing/` feature module suggested

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
