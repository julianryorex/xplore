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

Build a **3–4 screen onboarding**: value prop → sign in (FEAT-001) → create or join trip → location permission for map. Use existing `FadePageRoute` transitions and dark theme. Persist `onboarding_complete` in Hive or SharedPreferences.

## User stories

- As a first-time user, I want to understand what Xplore does before granting permissions.
- As an invitee, I want onboarding to skip trip creation and go straight to join.
- As the product, we want permission grant rates high enough for core map feature.

## Acceptance criteria

- [ ] Replace stub route with real onboarding screens
- [ ] Branch: create trip vs. join via deep link (FEAT-003)
- [ ] Request location permission with in-context copy (before map tab)
- [ ] Profile photo optional step (ties to map markers)
- [ ] Dev/debug controls removed or hidden from production home UI

## Success metrics

- Onboarding completion > 70%
- Location permission grant > 60%

## Dependencies

- FEAT-001, FEAT-002, FEAT-003 (partial — can show onboarding before join completes)

## Related code

- `lib/routes.dart` — `Paths.onboarding`
- `lib/screens/home_page.dart` — dev buttons to hide in prod
- `lib/constants/theme.dart` — reuse styling

## Open questions

- Skip onboarding for returning users with valid session only?
- Include notification permission pre-prompt (FEAT-012)?

## Notes / history

- 2025-06-22: Created
