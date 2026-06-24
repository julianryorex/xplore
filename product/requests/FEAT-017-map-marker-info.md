# FEAT-017: Map Marker Info & Last-Seen UX

| Field | Value |
|-------|-------|
| **ID** | FEAT-017 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | S |
| **Owner** | — |

## Problem

Map cubit TODOs mention InfoWindow with last updated. Users tap markers with no context — is Sarah's dot stale or is she actually at the izakaya?

## Proposed solution

Custom marker tap → bottom sheet with avatar, name, "Last seen 4 min ago", link to profile. Leverage existing stale opacity logic in README (>10 min fade).

## Acceptance criteria

- [ ] Tap marker opens member sheet
- [ ] Shows relative last update time from `LocationModel.lastUpdated`
- [ ] Visual stale state consistent with marker opacity

## Dependencies

- FEAT-015 (names/avatars)

## Related code

- `lib/features/map/bloc/map_cubit.dart` — TODO: InfoWindow
- `lib/features/location/models/location_models.dart`

## Notes / history

- 2025-06-22: Created
- 2026-06-23: Partial — marker `InfoWindow` now shows a relative "Last seen X
  ago" label (replacing the hardcoded `'Julian'`), backed by a unit-tested
  `formatLastSeen` / `isLocationStale` helper that also drives marker stale
  opacity. Full bottom-sheet + avatar UX still pending FEAT-015.
