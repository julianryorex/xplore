# FEAT-035: CI/CD Pipeline

| Field | Value |
|-------|-------|
| **ID** | FEAT-035 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | M |
| **Owner** | — |

## Problem

README roadmap lists CI/CD as TODO. Shipping monetization features without automated test/analyze gates increases regression risk.

## Proposed solution

GitHub Actions: `make gen`, `flutter analyze`, `flutter test` (excluding broken counter test or fix it), optional iOS build on macOS runner.

## Acceptance criteria

- [ ] PR checks run on every push
- [ ] Codegen step documented for CI
- [ ] Status badge in README (optional)

## Related code

- `Makefile`, `test/itinerary_demo_smoke_test.dart`

## Notes / history

- 2025-06-22: Created
