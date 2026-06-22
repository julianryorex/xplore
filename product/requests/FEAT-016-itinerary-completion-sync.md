# FEAT-016: Itinerary Checklist Completion Sync

| Field | Value |
|-------|-------|
| **ID** | FEAT-016 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

`LocationPlanModel.completed` drives checklist UI but toggling completion may not persist or sync — demo JSON is static. Groups can't coordinate "we've left the hotel" state.

## Proposed solution

Wire checklist toggle to Firebase patch on location item; show who completed and when (optional). Real-time listener updates tiles for all members.

## Acceptance criteria

- [ ] Tap to complete/uncomplete persists to cloud
- [ ] UI reflects other members' completions within sync SLA
- [ ] Works offline with queue flush

## Dependencies

- FEAT-006

## Related code

- `lib/features/itinerary/widgets/itinerary_tile.dart`
- `lib/features/itinerary/models/itinerary_models.dart` — `completed` field

## Notes / history

- 2025-06-22: Created
