# FEAT-015: Profile Cloud Sync

| Field | Value |
|-------|-------|
| **ID** | FEAT-015 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | M |
| **Owner** | — |

## Problem

Profile name is hardcoded; avatar is local file only. Map markers on other devices can't show your photo until you re-upload locally.

## Proposed solution

Sync display name and avatar to Firebase Storage + user profile doc. On login, hydrate `ProfileCubit` from cloud; on change, upload and update marker cache (`MarkerService`).

## Acceptance criteria

- [ ] Profile loads from Firebase on auth
- [ ] Avatar URL used by other clients for marker fetch
- [ ] Editable display name on profile page

## Dependencies

- FEAT-001

## Related code

- `lib/features/profile/bloc/profile_cubit.dart`
- `lib/features/map/services/marker_service.dart`

## Notes / history

- 2025-06-22: Created
