# FEAT-001: User Authentication

| Field | Value |
|-------|-------|
| **ID** | FEAT-001 |
| **Priority** | P0 |
| **Status** | `ready_for_dev` |
| **Revenue impact** | blocker |
| **Effort** | L |
| **Owner** | — |
| **Depth** | Full product spec (build-ready) |

> This is the **first domino**. FEAT-002 (trips), FEAT-003 (invites), FEAT-004 (remove hardcoded IDs), FEAT-015 (profile sync), FEAT-020 (billing), and FEAT-025 (analytics cohorts) all depend on a real, stable user identity. Build this first.

---

## 1. Problem & context

Today Xplore has **no concept of a real user**. Identity is a compile-time constant:

```dart
// lib/constants/constants.dart
const userId = '7d125e54-9de9-4a5c-bb15-29efacda4f9a';
```

```dart
// lib/features/profile/bloc/profile_cubit.dart
ProfileCubit() : super(const ProfileState(id: userId, name: 'Julian Rechsteiner')) { ... }
```

Consequences:

- Every device that installs the app **is the same person** on the map and in the gallery — locations all write to `locations/ph4kd/<same uid>`, photos all land in one bucket.
- There is **no account to bill**, no way to scope data per person, and no security boundary (Firebase paths are effectively public).
- Group travel is impossible: you cannot have "me" and "my friends" without distinct identities.

This blocks launch and every revenue path. It must ship before any multi-user behavior is trustworthy.

## 2. Goals & non-goals

### Goals

- Every session is backed by a **stable Firebase Auth UID**.
- Sign-in friction is minimal on iOS (one-tap Apple).
- The UID flows through the app via a single `AuthCubit`, replacing the `userId` constant (handoff to FEAT-004).
- A user profile document exists in the backend, keyed by UID, ready for trips/billing.
- Firebase Security Rules move from "open" to "authenticated + authorized".

### Non-goals (explicitly out of scope here)

- Trip creation / membership logic → FEAT-002.
- Invite/deep-link join → FEAT-003.
- Multi-provider account *linking* UI (e.g. merge Apple + Google) → later.
- Android sign-in providers → FEAT-030 (build provider-agnostic so this is cheap later).
- Email/password forms — we deliberately avoid passwords (see §4).

## 3. Key product decision: when do we ask users to sign in?

This is the most important product call in this spec. Three options:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Hard gate** | Sign-in is the first screen; nothing works until authenticated. | Simplest data model; UID always present. | Highest drop-off; invitees hit a wall before seeing trip value. |
| **B. Anonymous-first** | App boots with Firebase **anonymous auth**; prompt to "upgrade" (link Apple/Google) only when the user does something that needs durable identity (join trip, upload photo). | Lowest friction; great for invitees clicking a link; UID exists from second one. | Risk of orphaned anon accounts; must handle account upgrade/linking. |
| **C. Soft gate at value moment** | Browse a read-only demo, sign in to create/join a real trip. | Shows value first. | Demo vs. real state duplication; more UI states. |

**Recommendation: Option B (anonymous-first), upgrading to Apple/Google at the first identity-critical action.**

Rationale:
- The primary growth loop is **invite links** (FEAT-003). An invitee who taps a link in iMessage should land *inside the trip context* immediately; asking them to authenticate before they see anything kills the loop.
- Firebase anonymous auth gives us a real UID from launch, so location/gallery/profile code (FEAT-004) can be written **once** against `auth.uid` with no "logged out" branch.
- We upgrade the anon account in place (`linkWithCredential`) so the UID is preserved — no data migration when they finally sign in with Apple.

**Identity-critical actions that trigger the upgrade prompt:**
- Creating a trip (FEAT-002)
- Joining a trip via invite (FEAT-003)
- Uploading to the gallery (so photos are attributable and recoverable)
- Opting into location sharing (so a real person is on the map)

Until then, an anonymous user can look around but isn't yet "someone" to the group.

## 4. Auth providers

| Provider | Status | Why |
|----------|--------|-----|
| **Sign in with Apple** | Required (P0) | App Store policy mandates it when offering third-party sign-in on iOS; it's the lowest-friction option for our iOS-first audience. |
| **Google Sign-In** | Recommended (P0) | Common for the 25–40 traveler segment; cheap to add via Firebase. |
| **Anonymous** | Required (P0) | Underpins the anonymous-first flow in §3. |
| Email magic link | Deferred | Useful for Android/web later (FEAT-030); avoid password UIs entirely. |
| Phone | Deferred | SMS cost + friction; revisit if Apple/Google insufficient. |

**No passwords.** We never build a password field — it's a security liability and friction we don't need.

## 5. User flows

### 5.1 First launch (organic install)

1. App boots → `AuthCubit` silently creates/loads an **anonymous** session.
2. Onboarding (FEAT-005) explains value.
3. User taps **Create a trip** → upgrade prompt: "Save your trip — continue with Apple / Google."
4. On success, anon account is linked; profile doc created/updated; proceed to trip creation (FEAT-002).

### 5.2 Invitee via deep link (the critical path)

1. User taps invite link (FEAT-003) → app opens (or App Store → app).
2. `AuthCubit` ensures an anonymous session exists.
3. Join screen shows the trip preview (name, who's already in).
4. Tap **Join** → upgrade prompt (Apple/Google) → link → added to trip members.
5. Land on the trip's home/map with their own identity.

### 5.3 Returning user

1. App boots → Firebase restores the existing session (anon or upgraded) automatically. No re-auth.
2. If the session is upgraded, profile/name/avatar hydrate from cloud (FEAT-015).

### 5.4 Sign out / switch account

- Available from Profile. Sign-out returns to a fresh anonymous session (not a dead end).
- Warn if the current account is anonymous and signing out would orphan local-only data ("Sign in first to keep your trips").

### 5.5 Edge cases & handling

| Case | Handling |
|------|----------|
| Apple/Google cancelled mid-flow | Stay anonymous; non-blocking toast; user can retry. |
| `credential-already-in-use` (Apple account already linked to another UID) | Sign in to the *existing* account; surface "Welcome back". Local anon data is discarded (document this tradeoff; full merge is out of scope). |
| Network failure during sign-in | Inline error + retry; never leave a half-state. |
| Apple "Hide My Email" | Store the relayed email as-is; never assume a real address. |
| Apple returns name only on first authorization | Capture display name on that first call and persist immediately (Apple won't send it again). |
| Token expiry / revoked | Firebase refreshes silently; if refresh fails, fall back to a new anonymous session and prompt re-auth at next identity-critical action. |
| App reinstall | Anonymous UID is lost (expected). Upgraded users sign in again and recover via cloud. |

## 6. Data model

New backend user document, keyed by `auth.uid`. (Firestore recommended for user/trip docs even though location stays in RTDB; see FEAT-002 open question.)

```jsonc
// users/{uid}
{
  "uid": "string",                 // == auth.uid
  "displayName": "string",         // from Apple/Google, editable (FEAT-015)
  "email": "string|null",          // may be Apple private relay or null
  "photoUrl": "string|null",       // cloud avatar (FEAT-015)
  "providers": ["apple"],          // linked providers, for account UI later
  "isAnonymous": false,
  "createdAt": "timestamp",
  "lastSeenAt": "timestamp"
}
```

### App-side state

A new `AuthCubit` exposes auth state to the whole tree. Suggested shape (Freezed, matching existing patterns):

```dart
// lib/features/auth/bloc/auth_state.dart (sketch)
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unknown() = AuthUnknown;       // boot, before first resolve
  const factory AuthState.anonymous({required String uid}) = AuthAnonymous;
  const factory AuthState.authenticated({
    required String uid,
    required String displayName,
    String? email,
    String? photoUrl,
  }) = AuthAuthenticated;
}
```

`ProfileCubit` and `ProfileState.id` should consume `AuthCubit`'s uid rather than the constant.

## 7. Firebase Security Rules (must ship with this feature)

Today rules are effectively open. With auth we tighten:

- **RTDB `locations/{tripId}/{uid}`**: a user may write only their own `{uid}` node, and only read a trip they're a member of (membership check arrives with FEAT-002; until then, require `auth != null` and `uid == auth.uid` on write).
- **Storage `gallery/{tripId}/...`**: `request.auth != null`; tighten to trip membership in FEAT-014.
- **Firestore `users/{uid}`**: read/write only where `request.auth.uid == uid`.

Deliverable: a documented rules file (`firestore.rules` / RTDB rules JSON) committed alongside, even if full membership checks are stubbed until FEAT-002. **Do not ship auth without closing the open-rules hole.**

## 8. Analytics (events to emit — formalized in FEAT-025)

| Event | When |
|-------|------|
| `auth_anonymous_created` | First anonymous session established |
| `auth_upgrade_prompt_shown` | Upgrade sheet displayed (include trigger: create/join/upload/location) |
| `auth_sign_in_succeeded` | Apple/Google link/sign-in success (include provider) |
| `auth_sign_in_failed` | Failure (include reason bucket) |
| `auth_sign_out` | User signs out |

These feed the onboarding/invite funnels in VISION.md.

## 9. Acceptance criteria

- [ ] App boots into a valid Firebase session (anonymous) with a non-null UID, no user action required.
- [ ] Sign in with Apple works on a physical iOS device and links the anonymous account in place (UID preserved).
- [ ] Google Sign-In works and links in place.
- [ ] `AuthCubit` is provided at the app root (`MultiBlocProvider` in `main.dart`) and exposes uid + auth state stream.
- [ ] `ProfileCubit`/`ProfileState.id` reads UID from `AuthCubit`, not the `userId` constant (constant removed or quarantined — coordinate with FEAT-004).
- [ ] A `users/{uid}` document is created/updated on first authenticated session.
- [ ] Upgrade prompt appears at each identity-critical action (create/join/upload/location-opt-in) and nowhere else.
- [ ] Sign out returns to a fresh anonymous session (no dead-end logged-out screen).
- [ ] Firebase Security Rules require `auth != null` for all location/gallery/user writes; rules file committed.
- [ ] Apple edge cases handled: name captured on first authorization; Hide-My-Email tolerated; cancellation non-blocking.
- [ ] Analytics events from §8 fire (can be stubbed behind FEAT-025's wrapper).
- [ ] `flutter analyze` clean; new `AuthCubit` has unit tests with a mocked `FirebaseAuth`.

## 10. Success metrics

- 100% of production sessions have a non-null Firebase UID (anonymous or upgraded).
- Upgrade-prompt → sign-in completion > 80%.
- < 1% of sessions stuck in `AuthState.unknown` beyond 3s after boot.
- Zero cross-user data writes in QA (each device writes only its own location/gallery nodes).

## 11. Implementation plan (suggested, mapped to the codebase)

New feature module following the existing feature-first pattern:

```
lib/features/auth/
├── bloc/
│   ├── auth_cubit.dart        # wraps FirebaseAuth; anon bootstrap + link/upgrade
│   └── auth_state.dart        # Freezed states (§6)
├── data/
│   └── auth_repository.dart   # Firebase Auth + users/{uid} doc writes
└── presentation/
    └── upgrade_sheet.dart     # "Continue with Apple / Google" bottom sheet
```

Step-by-step:

1. **Deps**: add `firebase_auth`, `sign_in_with_apple`, `google_sign_in` to `pubspec.yaml`; run `make get` + `make gen`.
2. **Bootstrap**: in `main.dart`, after `initFirebase`, ensure an anonymous session before `runApp` (or expose `AuthState.unknown` and resolve in-app). Add `BlocProvider<AuthCubit>(lazy: false)` to the root `MultiBlocProvider`.
3. **AuthCubit**: emit `unknown → anonymous → authenticated`; methods `ensureAnonymous()`, `upgradeWithApple()`, `upgradeWithGoogle()`, `signOut()`.
4. **Profile handoff**: change `ProfileCubit` to read uid from `AuthCubit` (constructor injection or `context.read`), drop the hardcoded name default (hydrate from `users/{uid}` per FEAT-015 later).
5. **Constant quarantine**: leave `userId` in place only behind a debug/demo flag; production reads `AuthCubit.uid`. Full removal is FEAT-004.
6. **Rules**: write & commit `firestore.rules` and RTDB rules requiring `auth != null`; deploy to dev project.
7. **iOS config**: enable Sign in with Apple capability in Xcode (`Runner` target); add Google reversed-client-id URL scheme to `Info.plist`.
8. **Upgrade sheet UI**: build with existing dark theme primitives (`XploreColors`, Poppins, `XploreIconBtn`).
9. **Analytics**: emit §8 events (wrapper stub until FEAT-025).
10. **Tests**: unit-test `AuthCubit` with a fake `FirebaseAuth`; widget-test the upgrade sheet states.

### Related code touchpoints

- `lib/main.dart` — bootstrap + provider registration
- `lib/constants/constants.dart` — `userId` constant (quarantine → removal in FEAT-004)
- `lib/features/profile/bloc/profile_cubit.dart`, `profile_state.dart` — consume real uid
- `lib/features/location/bloc/location_cubit.dart` — `// TODO: use real user id from auth` (this resolves it)
- `lib/features/gallery/bloc/gallery_cubit.dart` — uploads should attribute to uid
- `lib/routes.dart` — onboarding/join entry points (coordinate with FEAT-005/003)

## 12. Risks

| Risk | Mitigation |
|------|------------|
| Anonymous account orphaning / bloat | TTL/cleanup job for anon accounts with no trip after N days; monitor count. |
| Apple review rejection (Apple sign-in rules) | Ensure Apple is offered with equal or higher prominence than Google; test on device pre-submit. |
| Account-merge confusion (`credential-already-in-use`) | Documented as "sign into existing account, anon data dropped" for MVP; revisit true merge later. |
| Shipping auth without rules → data exposure | Rules are a hard acceptance-criterion blocker (§7, §9). |

## 13. Open questions (with recommendations)

- **Firestore vs. RTDB for `users/{uid}`?** → Recommend Firestore for structured docs; keep live location in RTDB. Confirm in FEAT-002.
- **Do we ever fully remove the `userId` constant here or in FEAT-004?** → Quarantine here, remove in FEAT-004 to keep this PR focused.
- **Anonymous cleanup policy?** → Propose: delete anon accounts with no trip membership after 30 days; finalize with backend.

## 14. Notes / history

- 2025-06-22: Created from codebase audit.
- 2026-06-22: Expanded into full build-ready product spec; status → `ready_for_dev`. Chosen direction: anonymous-first with in-place upgrade to Apple/Google at identity-critical actions.
