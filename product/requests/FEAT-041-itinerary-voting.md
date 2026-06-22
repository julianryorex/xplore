# FEAT-041: Collaborative Itinerary Voting

| Field | Value |
|-------|-------|
| **ID** | FEAT-041 |
| **Priority** | P4 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

`PlanModel.favorited` exists in schema but no voting UI. Groups argue in chat about dinner spots instead of in-app consensus.

## Proposed solution

Poll or upvote on candidate locations before locking into the day plan. Organizer finalizes winners.

## Related code

- `lib/features/itinerary/models/itinerary_models.dart` — `favorited`

## Notes / history

- 2025-06-22: Created
