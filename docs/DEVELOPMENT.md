# Development

Engineering reference for working on Xplore. The [README](../README.md) covers
the high-level "what" and a minimal run; this file covers the details.

## Toolchain

- **FVM-pinned Flutter `3.44.0` (Dart `3.12.x`)** — matches `.fvmrc`, `pubspec.yaml`,
  and `pubspec.lock`. Install once with `fvm install` then
  `fvm use 3.44.0 --skip-pub-get`. Use `fvm flutter ...` / `fvm dart ...` for ad
  hoc commands, or the Makefile targets below.
- **Code generation is required.** `lib/generated/` (Freezed / json_serializable)
  is git-ignored. Run `make gen` before `analyze`, `test`, or any build, or you'll
  hit missing `part` file errors.
- **Local storage is Hive CE (`hive_ce`)** — the maintained community fork of the
  discontinued `hive`. `TypeAdapter`s are hand-written (see
  `lib/features/gallery/models/image_models_adapters.dart`), not generated.

## Makefile commands

| Command | Description |
|---------|-------------|
| `make get` | Install Flutter dependencies with FVM |
| `make gen` | Run build_runner (Freezed, json_serializable) |
| `make format` | Apply Dart fixes + format app/test code (120-char width) |
| `make check-format` | CI-style format check |
| `make build-ios` | Build iOS release |
| `make clean` | Clean build artifacts and generated code |
| `make reboot` | Full rebuild: clean → get → gen → build-ios |

## Architecture

```
lib/
├── main.dart                  # Firebase/Hive CE/Gemini init, MultiBlocProvider root
├── routes.dart                # Named routes with FadePageRoute transitions
├── constants/                 # Colors, theme (dark + Poppins), extensions
├── core/                      # Shared UI primitives (navbar, header, avatar marker)
├── features/
│   ├── auth/                  # Sign-in, AuthCubit/AuthGate
│   ├── gallery/               # Cubit, Freezed models, Hive CE repository, picker/grid/zoom
│   ├── itinerary/             # Cubit, Freezed models, card & tile widgets
│   ├── location/              # Cubit + models for GPS sync
│   ├── map/                   # Cubit + marker rendering service
│   ├── nav/                   # Bottom nav cubit
│   ├── notifications/         # Notifications feed UI
│   ├── profile/               # Cubit + state for profile photo
│   └── trip/                  # Trip entity, invites/join flow, deep links
├── screens/                   # Page-level widgets
└── utilities/                 # Screen helpers, structured logging, JSON asset loader
```

**Key patterns:**
- **Feature-first modular structure** — each domain owns its bloc, models, presentation.
- **Cubit-based state management** (flutter_bloc).
- **Immutable models** via Freezed + json_serializable codegen.
- **Offline-first data layer** — Hive CE for local cache, Firebase for cloud sync.
- **Repository pattern** for the gallery; other features talk to Firebase directly from cubits.
- **Cubits never import cubits** — cross-feature state lives in a plain service
  injected into each cubit. See [`PATTERNS.md`](PATTERNS.md).

## Environment configuration

`assets/.env` is git-ignored and declared as an asset in `pubspec.yaml`, so it
**must exist** for the app to build. Copy the template:

```bash
cp assets/.env.example assets/.env
```

The app **builds and runs with empty keys** — it only fails at the points that
need real credentials (sign-in, Firebase reads/writes, Maps tiles, Gemini calls).

| Variable | Purpose |
|----------|---------|
| `APPLE_API_KEY` | Firebase iOS API key (sign-in + Firebase services) |
| `MACOS_API_KEY` | Firebase macOS API key |
| `GEMINI_API_KEY` | Google Gemini (AI itinerary generation) |
| `DISABLE_REALTIME_LOCATIONS` | `true` to skip RTDB location sync locally |
| `LOCATION_INTERVAL_UPDATE` | Optional GPS sync interval (seconds) |

The Google Maps key is injected separately as the `MAPS_API_KEY` Xcode build
setting (e.g. via an xcconfig or CI environment variable), not through `.env`.

### Full functionality

For working sign-in / cloud / maps / AI you also need:
- A Firebase project (Realtime Database + Storage) and matching
  `GoogleService-Info.plist` files for the iOS/macOS targets.
- A Google Maps API key supplied as `MAPS_API_KEY` at build time.
- Backend/auth provisioning. Infra is managed with Terraform under `infra/`
  (see [`infra/README.md`](../infra/README.md)).

None of these are needed just to compile and launch the UI.

## Platform support & CI

- Xplore is validated through the **iOS** target. Do not use Linux runners for
  app validation or golden refreshes — Flutter golden snapshots depend on host
  text rasterization and the checked-in baselines are Apple CI baselines.
- [`codemagic.yaml`](../codemagic.yaml) installs deps, generates sources, builds
  the iOS app without code signing, and runs the itinerary card golden test on a
  Mac build machine. This is an iOS CI workflow only.

## Product & roadmap

GitHub Issues are the execution queue; product specs live in `product/`.
For prioritized feature requests with acceptance criteria, see
[`product/BACKLOG.md`](../product/BACKLOG.md). Current shipped-vs-assumed status
is in [`product/CURRENT_STATE.md`](../product/CURRENT_STATE.md).
