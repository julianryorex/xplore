# Testing Sign in with Apple

How to verify the Apple auth flow (FEAT-001). Two layers: automated tests that
run anywhere, and the real end-to-end flow that needs a Mac + the Apple/Firebase
console setup.

## 1. Automated tests (run anywhere, no console setup)

The Apple credential request is injected via `AuthService`'s
`AppleCredentialRequester`, so these never touch Apple's servers and run
headlessly (including on Linux/CI).

```bash
fvm flutter test test/features/auth   # auth suite only
fvm flutter test                       # full suite
```

Coverage:

- `auth_service_test.dart` — success, first-authorization name capture,
  no-overwrite when Apple omits the name, user cancel → `AuthCancelledException`,
  other errors → `AuthFailureException`, missing identity token.
- `auth_cubit_test.dart` — `signInWithApple()` drives the stream to
  `authenticated`.
- `sign_in_page_test.dart` — the Apple + Google buttons render.

These prove the wiring/logic but **not** that Apple + Firebase issue a real
session — that needs the device path below.

## 2. End-to-end on a Mac

### Prerequisites (one-time, out-of-band)

1. **Apple Developer** — App ID `com.olympuslabs.xplore`: enable *Sign in with
   Apple*; create a Services ID and a `.p8` Key (note the Team ID + Key ID).
2. **Firebase Console** (`xplore-a7012`) → Authentication → Sign-in method →
   enable **Apple** and paste the Services ID / Team ID / Key ID / `.p8`.
3. The simulator/device must be signed into an Apple ID (Settings → Apple
   Account). Sign in with Apple works on the iOS Simulator, not just physical
   devices.

> Until the Firebase Apple provider is enabled, the real flow fails at the
> Firebase credential exchange and surfaces as an inline `AuthFailureException`
> on the sign-in page — which still confirms the button → Apple sheet → Firebase
> path is firing.

### Run

```bash
cp assets/.env assets/.env            # ensure the git-ignored env file exists
fvm flutter pub get
cd ios && pod install && cd ..        # picks up sign_in_with_apple
fvm flutter run                        # choose an iOS simulator/device
```

In Xcode (one-time sanity check): open `ios/Runner.xcworkspace` → Runner target
→ **Signing & Capabilities** and confirm "Sign in with Apple" is present (it
reads `ios/Runner/Runner.entitlements`) and a development team is set.

### Manual checklist

- **Happy path:** onboarding → **Sign in with Apple** → native sheet → confirm →
  lands on Home. Verify a `users/{uid}` doc exists in the `xplore-app` Firestore
  database with `providers: ['apple']` and a `displayName`.
- **Cancel:** dismiss the Apple sheet → returns to the idle sign-in screen, no
  error, button re-enabled.
- **Returning user:** kill + relaunch → skips straight to Home (session
  restored).
- **Sign out:** Profile → sign out → returns to onboarding/sign-in.

### Re-testing the first-authorization name capture

Apple returns the name **only on the first authorization** for a given Apple ID
+ app; afterwards you get just the user identifier. To exercise the
name-capture branch again, revoke the app's authorization first:

- On device/simulator: **Settings → Apple Account → Sign in with Apple →
  (the app) → Stop Using Apple ID**, or
- At [appleid.apple.com](https://appleid.apple.com) → Sign in with Apple → stop
  using.

The next sign-in is then treated as a first authorization and `displayName` is
populated from `givenName` / `familyName`.
