# FEAT-023: Trip Recap & Shareable Link

| Field | Value |
|-------|-------|
| **ID** | FEAT-023 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | M |
| **Owner** | — |

## Problem

After a trip, memories live only in the app. No viral loop for non-users to discover Xplore or for organizers to share highlights.

## Proposed solution

Post-trip **recap page**: map route snapshot, top gallery photos, itinerary stats. Public or link-only share URL (read-only, no live location). CTA: "Plan your own trip with Xplore."

## Acceptance criteria

- [ ] Generate recap after trip end date or manual trigger
- [ ] Share sheet with web preview (Firebase Hosting or similar)
- [ ] Privacy: no live location on public recap

## Dependencies

- FEAT-006, FEAT-011

## Notes / history

- 2025-06-22: Created
