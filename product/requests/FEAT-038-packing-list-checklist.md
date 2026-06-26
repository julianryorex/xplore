# FEAT-038: Collaborative Packing List & Pre-Trip Checklist

| Field | Value |
|-------|-------|
| **ID** | FEAT-038 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Trips need prep — packing and shared to-dos ("book the airport transfer", "who's bringing the speaker") — and Xplore has none of it, so groups fall back to notes apps and group chats. It's a universal, low-effort feature that adds pre-trip engagement and natural group coordination.

## Proposed solution

Shared per-trip checklists: a **packing list** and a **to-do / prep list**. Items can be checked off, assigned to / claimed by a member, and are realtime across the group. Later: smart starter suggestions from destination, weather, and duration (ties to FEAT-037 data). Works equally for solo travelers (just a personal list).

## User stories

- As an organizer, I want a shared to-do list, so prep isn't all on me.
- As a member, I want to claim "bringing the speaker", so we don't double up or forget.
- As a solo traveler, I want a simple packing checklist, so I don't forget essentials.

## Acceptance criteria

- [ ] Per-trip packing + to-do lists stored under the trip (Firestore), realtime
- [ ] Add / check / delete items; optional assignee/claim
- [ ] Solo and group both first-class (no group required)
- [ ] Empty-state starter template (generic) on first open

## Success metrics

- % of trips that create at least one checklist
- Pre-trip (before start date) sessions vs. baseline

## Dependencies

- FEAT-002 (trip). Optional: FEAT-024 (roles for assignment), FEAT-037 (smart suggestions later)

## Related code

- `lib/features/trip/` (trip-scoped storage pattern), new `checklist` feature module

## Open questions

- One list per trip vs. multiple named lists?
- Reuse a member's packing list across their trips (personal template)?

## Notes / history

- 2026-06-26: Created. From the UX gap review — pre-trip coordination is currently absent.
