# FEAT-024: Trip Organizer Role & Permissions

| Field | Value |
|-------|-------|
| **ID** | FEAT-024 |
| **Priority** | P2 |
| **Status** | `backlog` |
| **Revenue impact** | enabler |
| **Effort** | M |
| **Owner** | — |

## Problem

No distinction between who can edit itinerary vs. view-only. Billing assumes an **organizer** pays for the group; role model must exist in data and rules.

## Proposed solution

Roles: `owner`, `organizer`, `member`. **Every member can edit the itinerary**, invite, vote and buy a Trip Pass for the trip (FEAT-020). Roles gate only the destructive and administrative actions: removing members, deleting the trip, transferring ownership, and Hosts broadcast messages (FEAT-045). This replaces the owner-only editing model recorded in FEAT-006.

## Acceptance criteria

- [ ] Role on trip membership record
- [ ] All members can edit the itinerary; edits are attributed and undoable
- [ ] Member removal, trip deletion and ownership transfer limited to owner/organizer in UI and Firebase rules

## Dependencies

- FEAT-002, FEAT-006

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
