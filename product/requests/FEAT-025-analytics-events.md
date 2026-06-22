# FEAT-025: Analytics & Funnel Events

| Field | Value |
|-------|-------|
| **ID** | FEAT-025 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | enabler |
| **Effort** | M |
| **Owner** | — |

## Problem

No instrumentation for north-star metrics in [VISION.md](../VISION.md). Cannot optimize onboarding, invites, or paywall without events.

## Proposed solution

Firebase Analytics (or Mixpanel) with typed event helpers. MVP events: `sign_up`, `trip_created`, `invite_sent`, `invite_accepted`, `ai_itinerary_generated`, `gallery_upload`, `subscription_started`, `paywall_viewed`.

## Acceptance criteria

- [ ] Analytics wrapper in `lib/utilities/` or `lib/core/analytics/`
- [ ] Events fired at funnel steps above
- [ ] DebugView verified on iOS simulator

## Dependencies

- FEAT-001 (user identity for cohorts)

## Notes / history

- 2025-06-22: Created
