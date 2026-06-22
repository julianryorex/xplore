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

Integrate **RevenueCat** or native StoreKit 2: products for monthly Plus and trip pass. Entitlements stored in Firebase custom claims or RevenueCat webhook → Firestore `users/{uid}/subscription`. Paywall surfaces: second trip creation, member cap, AI regen, storage limit.

## User stories

- As an organizer, I want to upgrade one trip for the whole group, so everyone gets Plus benefits.
- As a free user hitting limits, I want a clear upgrade path, not a cryptic error.

## Acceptance criteria

- [ ] App Store subscription products configured
- [ ] Restore purchases works
- [ ] Trip-level or user-level entitlement model implemented
- [ ] Limits enforced: trips, members, storage, AI (see sibling FEATs)
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
