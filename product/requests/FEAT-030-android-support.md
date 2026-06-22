# FEAT-030: Android Platform Support

| Field | Value |
|-------|-------|
| **ID** | FEAT-030 |
| **Priority** | P3 |
| **Status** | `backlog` |
| **Revenue impact** | indirect |
| **Effort** | L |
| **Owner** | — |

## Problem

README lists Android as roadmap item. `firebase_options.dart` only configures iOS/macOS — same gap blocks web/Linux runtime.

## Proposed solution

Add Android Firebase config, Google Maps API key, Play Store build pipeline. Test location, gallery, auth on Android 13+.

## Acceptance criteria

- [ ] `flutter run` on Android emulator
- [ ] Firebase Auth, RTDB, Storage functional
- [ ] Play Store internal testing track build

## Dependencies

- FEAT-001, FEAT-035 (CI helps)

## Related code

- `lib/firebase_options.dart`
- `android/` project folder

## Notes / history

- 2025-06-22: Created
