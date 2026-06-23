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

## Other conventions (see README "Key patterns")

- **Feature-first modules** — each domain owns its `bloc/`, `models/`,
  `services/`, and `presentation/`.
- **Immutable state** via Freezed (`@freezed`), generated into `lib/generated/`.
- **Offline-first data** — Hive for local cache, Firebase for cloud sync.
- **Repository pattern** for data abstractions (e.g. gallery over Hive).
