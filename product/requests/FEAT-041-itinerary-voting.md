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

Scout (FEAT-037), the owner or an admin opens a vote with two or three options for a slot (FEAT-024); any member can suggest an option, and an admin decides whether it goes to a vote; the group votes with a tap, each vote has a closing time, and the winner goes into the plan automatically when it closes. Open votes show on the Today view (FEAT-018). Available on every plan, including Free.

## Related code

- `lib/features/itinerary/models/itinerary_models.dart` — `favorited`

## Notes / history

- 2025-06-22: Created
- 2026-11-22: Aligned with the launch-post vision ([launch-post.html](../launch-post.html)).
