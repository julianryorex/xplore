# FEAT-008: Developer tools page

| Field | Value |
|-------|-------|
| **ID** | FEAT-008 |
| **Priority** | P1 |
| **Status** | `done` |
| **Revenue impact** | none (hygiene) |
| **Effort** | S |
| **Owner** | — |

## Problem

The Home screen carried a `kDebugMode` block of raw debug controls (Upload /
Delete Hive / Trigger error). It cluttered the production-facing layout, leaked
debug affordances into the most-seen screen, and blocked the FEAT-005 acceptance
criterion "dev controls removed from production home".

## Proposed solution

Move the debug controls into a dedicated, `kDebugMode`-gated **Developer** page
reachable from Profile, and remove the block from Home.

- `lib/features/dev/presentation/dev_tools_page.dart` — glass list of tools:
  upload sample to gallery, delete Hive caches, trigger trip error state.
- `Paths.dev` (`/dev`) route in `lib/routes.dart`.
- `kDebugMode`-gated "Developer" entry on `profile_page.dart`.
- Debug block removed from `home_page.dart`.

## User stories

- As a developer, I want debug utilities in one out-of-the-way place, so the
  production Home stays clean.

## Acceptance criteria

- [x] Debug controls removed from `home_page.dart`.
- [x] Developer page wires `GalleryCubit.uploadToGallery/deleteAll`,
  `ProfileCubit.deleteAll`, `TripCubit.debugTriggerError`.
- [x] Entry and page are gated behind `kDebugMode`.
- [x] Satisfies FEAT-005 AC "dev controls removed from production home."

## Dependencies

- None. Unblocks a FEAT-005 acceptance criterion.

## Related code

- `lib/features/dev/presentation/dev_tools_page.dart`
- `lib/screens/profile_page.dart` — `_DeveloperButton`
- `lib/screens/home_page.dart` — debug block removed
- `lib/routes.dart` — `Paths.dev`

## Open questions

- None.

## Notes / history

- 2026-06-26: Created and shipped on `feat/trip-creation-dev-home`.
