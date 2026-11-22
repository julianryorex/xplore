# Codebase patterns

Conventions that outlive any single feature. Read this before adding a cubit,
service, or cross-feature dependency.

## Cubits never import or depend on other cubits

A cubit must **not** import, hold, or `context.read` another cubit. Cross-feature
state (e.g. the current user's UID / auth state) is owned by a plain **service**
— no Flutter or `flutter_bloc` imports — and composed into each cubit via
**constructor injection**.

Why: it keeps features decoupled and independently testable, avoids hidden
ordering dependencies between providers, and gives a single source of truth for
shared state instead of one cubit reaching into another.

### Service as composition

- Keep service logic in its own file (`features/<x>/services/<x>_service.dart`).
- Trivial logic may live inside the owning cubit, but **never** to bridge two
  cubits — that's exactly what a service is for.
- A service is a plain Dart class. It can wrap SDKs (Firebase, Google Sign-In),
  expose streams/getters, and be mocked in tests.
- Services and cubits use the shared `createLogger('<ComponentName>')` helper
  from `utilities.dart` for diagnostics. Prefer named loggers over `print`,
  `debugPrint`, or manually embedded severity prefixes; the helper already
  applies the component prefix and release-mode log level.

## Worked example: `AuthService`

`AuthService` is the single source of UID truth. It wraps `FirebaseAuth` +
Google sign-in and upserts the Firestore `users/{uid}` profile. It is created
once at the app root and injected into every cubit that needs identity.

```
                 ┌──────────────────────────────────────────────┐
                 │ AuthService (FirebaseAuth + Google + Firestore)│
                 └──────────────────────────────────────────────┘
                    │            │            │            │
                    ▼            ▼            ▼            ▼
               AuthCubit    ProfileCubit  LocationCubit  MapCubit
            (auth UI state) (reads uid)   (reads uid)   (reads uid)
                    │
                    ▼
                AuthGate (widget)
```

- `AuthCubit` composes `AuthService` and exists only to expose auth UI state
  (`unknown` / `unauthenticated` / `authenticated`) to the widget tree
  (`AuthGate`). It imports no other cubit.
- `ProfileCubit`, `LocationCubit`, `MapCubit` compose the **same** `AuthService`
  instance to read `currentUid`. They do **not** `context.read<AuthCubit>()`.

Wiring (see `lib/main.dart`): one `AuthService` is provided via
`RepositoryProvider` and passed into each cubit's constructor, so every cubit
shares the same instance.

## Auth-dependent cubits

Choose deliberately between action-driven and session/reactive auth patterns:

- **Action-driven cubits** (`MapCubit`, `ProfileCubit`) read
  `AuthService.currentUid` at call time and no-op or fail fast when it is null.
  Their work is triggered after the auth gate by user actions, timers, or
  explicit refreshes, so they do not need their own auth subscription.
- **Session/reactive cubits** (`AuthCubit`, `TripCubit`) subscribe to
  `AuthService.authStateChanges()`, load on sign-in, and clear any per-user
  state plus subscriptions on sign-out. Use this when the UI must reflect
  session data without a user action.
- **Cross-cubit reactivity** uses a stream mixin instead of one cubit importing
  another. `TripCubit` publishes `TripState` through `TripStreamMixin`; consumers
  like `GalleryCubit` and `LocationCubit` subscribe to cache the active trip id.
  Consumers cancel only their own `StreamSubscription` in `close()` and never
  close the shared broadcast controller.

## Module boundaries: three layers, imports point down

> **Status: target architecture, not yet enforced.** As of 2026-11-21 the code
> has 117 feature-to-feature imports across 50 files, `lib/core` imports
> features, and `lib/shared/` and `make check-imports` do not exist yet. New
> code should follow the rule; existing violations are migrated one feature at
> a time.

```
┌──────────────────────────────────────────────────────────────┐
│ Composition   home · agent · onboarding · dev · root shell · │
│               lib/screens                                    │
└──────────────────────────────────────────────────────────────┘
        │ may import                                    │
        ▼                                               │
┌───────────────────────────────────────────────────┐   │
│ Features   trip · itinerary · gallery · profile · │   │
│            map · location · auth                  │   │
└───────────────────────────────────────────────────┘   │
        │ may import                                    │
        ▼                                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Shared domain (lib/shared/)   services · models · state types│
└──────────────────────────────────────────────────────────────┘
```

- **Composition** exists to stitch features together, so it may import
  features and the shared layer.
- **Features** import the shared layer only. A feature never imports another
  feature — not its cubit, models, services, or widgets.
- **Shared domain** imports no feature and nothing from composition.

Why: imports that only point down cannot form cycles (today: `trip` ↔
`itinerary`, `trip` ↔ `home`, `trip` ↔ `onboarding`, `auth` ↔ `onboarding`,
`home` ↔ `agent`, `trip` → `map` → `location` → `trip`), each feature can be tested with only the shared layer, and a
feature's internals can change without breaking its neighbours.

### When a feature needs something from another feature

Try these in order; moving code to shared is the last resort, not the first:

1. **Let composition pass it down.** If a gallery widget needs a profile
   avatar, the screen that composes both reads the profile and passes the
   avatar in as a parameter.
2. **Merge the features** if they import each other heavily in both
   directions — they are probably one module.
3. **Move the smallest piece to shared.** Move the one converter or state type
   that is needed, not the file it happens to live in.

### Keeping the shared layer small

The shared layer is the easy fix for every violation, so it has its own rules:

- **Two real consumers.** Code moves to shared only when a second feature
  needs it. Code used by one feature stays there, however general it looks.
- **Allow-list of contents.** Data models, services (interfaces and
  implementations), and state types published across features (e.g.
  `TripState`, `TripStreamMixin`). No widgets, no cubits, no feature-specific
  logic. Nothing in shared imports `flutter_bloc` or Flutter widgets.
- **Organised by domain, not by kind.** `shared/trip/`, `shared/itinerary/`,
  `shared/auth/` — not `shared/models/` and `shared/services/`. Shared domains
  must not import each other in a cycle.

### Enforcement (planned)

A `make check-imports` target, run as part of `make verify`, will fail on:

- a file under `lib/features/<x>/` importing `lib/features/<y>/`;
- a file under `lib/shared/` importing a feature, `flutter_bloc`, or Flutter
  widgets;
- an import cycle between shared domains.

It will also print the shared layer's file count on each run, so steady growth
there is visible in review.

## Other conventions (see README "Key patterns")

- **Feature-first modules** — each domain owns its `bloc/`, `presentation/`,
  and whatever `models/` and `services/` only it uses; anything a second
  feature needs lives in the shared layer (see "Module boundaries" above).
- **Immutable state** via Freezed (`@freezed`), generated into `lib/generated/`.
- **Offline-first data** — Hive CE (`hive_ce`) for local cache, Firebase for cloud sync.
- **Repository pattern** for data abstractions (e.g. gallery over Hive CE).
