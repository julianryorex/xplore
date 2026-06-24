# FEAT-036: Test Suite

| Field | Value |
|-------|-------|
| **ID** | FEAT-036 |
| **Priority** | P3 |
| **Status** | `in_progress` |
| **Revenue impact** | indirect |
| **Effort** | L |
| **Owner** | — |

## Problem

`test/widget_test.dart` is the default counter test and fails. Only itinerary smoke + golden tests exist. Billing and auth need coverage before revenue features ship.

## Proposed solution

Replace counter test. Add cubit unit tests (itinerary parse, gallery state, location timer mock), widget tests for key screens, integration test for demo load path.

## Acceptance criteria

- [ ] `flutter test` passes in CI
- [ ] Coverage for P0 cubits once implemented
- [ ] Golden tests updated when UI changes

## Related code

- `test/widget_test.dart`, `test/itinerary_demo_smoke_test.dart`

## Notes / history

- 2025-06-22: Created
- 2026-06-24: Test infrastructure landed via PR #80 (golden helpers, cubit unit tests for auth/trip/gallery/location). Counter template test removed. Full P0 coverage and CI gate remain open.
