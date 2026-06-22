# FEAT-021: AI Itinerary Credits & Usage Limits

| Field | Value |
|-------|-------|
| **ID** | FEAT-021 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | direct |
| **Effort** | M |
| **Owner** | — |

## Problem

Unlimited Gemini calls would burn API budget and remove upsell leverage. Need quotas aligned with [MONETIZATION.md](../MONETIZATION.md).

## Proposed solution

Track AI generations per user/trip in Firestore. Free: 0–1 trial generation. Plus: monthly quota. Consumable IAP for credit packs. Block UI with upgrade/credit purchase when exhausted.

## Acceptance criteria

- [ ] Server-side or tamper-resistant client quota check before Gemini call
- [ ] Credit balance visible in AI flow
- [ ] Consumable IAP for credit bundles

## Dependencies

- FEAT-010, FEAT-020

## Notes / history

- 2025-06-22: Created
