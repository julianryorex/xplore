# FEAT-013: Background Location Updates

| Field | Value |
|-------|-------|
| **ID** | FEAT-013 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | L |
| **Owner** | — |

## Problem

`LocationCubit` uses a foreground timer and notes TODOs for background fetch. When the app is backgrounded, friends see stale markers — undermining the core "where is everyone" promise.

## Proposed solution

Implement iOS background location updates (with clear UX and App Store privacy strings), configurable interval by tier (Plus = faster updates). Keep stale-marker opacity behavior for >10 min old positions.

## User stories

- As a trip member, I want my location to update when the app is in my pocket, so friends can find me.
- As a privacy-conscious user, I want to pause sharing or leave trip location mode.

## Acceptance criteria

- [ ] Background location on iOS with `UIBackgroundModes`
- [ ] Pause / stop sharing toggle in profile or map
- [ ] Battery-conscious default interval on free tier
- [ ] Verify foreground timer still works (existing TODO)

## Success metrics

- Median location age < 5 min during active trip hours
- Uninstall rate not increased vs. baseline (privacy backlash check)

## Dependencies

- FEAT-001, FEAT-004

## Related code

- `lib/features/location/bloc/location_cubit.dart`

## Notes / history

- 2025-06-22: Created
