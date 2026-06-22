# FEAT-014: Trip-Scoped Gallery & Storage Paths

| Field | Value |
|-------|-------|
| **ID** | FEAT-014 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | enabler |
| **Effort** | S |
| **Owner** | — |

## Problem

Gallery uploads hardcode `gallery/ph4kd/`. Multi-trip and storage metering (FEAT-022) require per-trip isolation and aggregate size tracking.

## Proposed solution

Parameterize all Storage paths and Hive box names with active trip ID. Clear trip cache on switch. Enforce Firebase Storage rules: only trip members can read/write trip prefix.

## Acceptance criteria

- [ ] `uploadImage` uses `gallery/{activeTripId}/{imageId}`
- [ ] Hive keys namespaced or cleared on trip switch
- [ ] Security rules documented and deployed

## Dependencies

- FEAT-004

## Related code

- `lib/features/gallery/bloc/gallery_cubit.dart` — line 156

## Notes / history

- 2025-06-22: Created
