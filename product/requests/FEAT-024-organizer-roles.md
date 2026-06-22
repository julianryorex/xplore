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

Roles: `owner`, `organizer`, `member`. Only owner/organizer edit itinerary, invite, upgrade trip. Transfer ownership flow.

## Acceptance criteria

- [ ] Role on trip membership record
- [ ] UI hides edit affordances for members
- [ ] Firebase rules enforce write by role

## Dependencies

- FEAT-002, FEAT-006

## Notes / history

- 2025-06-22: Created
