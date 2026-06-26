# FEAT-005: Onboarding Flow

| Field | Value |
|-------|-------|
| **ID** | FEAT-005 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | M |
| **Owner** | — |

## Problem

`Paths.onboarding` routes to an empty `Container()`. New users land on the home screen with demo affordances ("Load data", "Delete Hive") and no explanation of value or permission prompts (location, photos, notifications).

## Proposed solution

Build a **3–4 screen onboarding**: value prop → sign in (FEAT-001) → **optional profile
setup (photo + handle)** → create or join trip → location permission for map. Use existing
`FadePageRoute` transitions and dark theme. Persist `onboarding_complete` in Hive or
SharedPreferences.

**Profile setup step (ties to FEAT-015).** After sign-in, the account already has a
seeded profile (`displayName` + provider `photoUrl` + a generated `username`). Offer a
**skippable** step where the user can replace their photo and edit their handle; whatever
they set writes through to `users/{uid}` via `ProfileCubit` (same write path as the Edit
Profile page), and anything skipped stays editable later. Keep it optional so it doesn't
depress the >70% completion target. Apple users (no provider photo) see the initial-letter
fallback with a clear "Add a photo" affordance.

## User stories

- As a first-time user, I want to understand what Xplore does before granting permissions.
- As an invitee, I want onboarding to skip trip creation and go straight to join.
- As the product, we want permission grant rates high enough for core map feature.

## Acceptance criteria

- [ ] Replace stub route with real onboarding screens
- [ ] Branch: create trip vs. join via deep link (FEAT-003)
- [ ] Request location permission with in-context copy (before map tab)
- [ ] Optional profile-setup step: photo **and** handle, skippable, persists to
      `users/{uid}` via `ProfileCubit` (FEAT-015) and remains editable later
- [ ] Dev/debug controls removed or hidden from production home UI

## Success metrics

- Onboarding completion > 70%
- Location permission grant > 60%

## Dependencies

- FEAT-001, FEAT-002, FEAT-003 (partial — can show onboarding before join completes)
- FEAT-015 (profile cloud sync) — the profile-setup step writes through its `ProfileCubit`
  write path; can ship onboarding with photo-only first if FEAT-015 handle work lags

## Related code

- `lib/routes.dart` — `Paths.onboarding`
- `lib/screens/home_page.dart` — dev buttons to hide in prod
- `lib/constants/theme.dart` — reuse styling

## Open questions

- Skip onboarding for returning users with valid session only?
- Include notification permission pre-prompt (FEAT-012)?

## Notes / history

- 2025-06-22: Created
- 2026-06-26: Added the optional profile-setup step (photo + handle) and wired it to
  FEAT-015's `ProfileCubit` write path so onboarding seeds/customizes the cloud profile.
