# FEAT-001: User Authentication

| Field | Value |
|-------|-------|
| **ID** | FEAT-001 |
| **Priority** | P0 |
| **Status** | `backlog` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |

## Problem

Every feature assumes a single hardcoded user (`userId` in `lib/constants/constants.dart`). Real groups need sign-in, identity on the map, and per-user gallery attribution. Without auth there is no account to bill, no security rules, and no way to join a trip as yourself.

## Proposed solution

Integrate **Firebase Authentication** with Apple Sign-In (required for iOS) and email magic link or Google as secondary. Introduce an `AuthCubit` that exposes the current user ID and auth state to the app root. Gate the main shell behind signed-in state.

## User stories

- As a new user, I want to sign in with Apple, so that I can join my friends' trip securely.
- As a returning user, I want to stay signed in, so that I don't re-auth every app open.
- As the product, we need a stable UID for Firebase paths and future billing.

## Acceptance criteria

- [ ] Firebase Auth initialized in `main.dart` alongside existing Firebase setup
- [ ] Sign-in / sign-out UI (can live on onboarding or profile)
- [ ] `AuthCubit` provides `userId`, display name, and auth stream to descendants
- [ ] All references to hardcoded `userId` read from auth (see FEAT-004)
- [ ] Firebase Security Rules documented for RTDB / Storage keyed by `auth.uid`

## Success metrics

- 100% of production sessions have a non-null Firebase UID
- Sign-in completion rate > 80% of onboarding starts

## Dependencies

- Firebase project with Auth providers enabled
- Apple Developer Sign in with Apple capability

## Related code

- `lib/constants/constants.dart` — `userId` constant to remove
- `lib/features/location/bloc/location_cubit.dart` — TODO: use real user id from auth
- `lib/features/profile/bloc/profile_cubit.dart` — hardcoded name and id
- `lib/main.dart` — add `AuthCubit` to `MultiBlocProvider`

## Open questions

- Email-only fallback for Android later (FEAT-030)?
- Link anonymous sessions if user browsed demo first?

## Notes / history

- 2025-06-22: Created from codebase audit
