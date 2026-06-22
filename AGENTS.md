# AGENTS.md

## Cursor Cloud specific instructions

Xplore is a Flutter group-travel app (state via flutter_bloc/Cubit, Freezed +
json_serializable models, Hive local cache, Firebase backend, Google Maps,
Gemini). See `README.md` and the `Makefile` for the canonical commands
(`make get`, `make gen`, `make format`, `make check-format`).

### Toolchain / setup notes (non-obvious)
- Use **Flutter 3.32.x (Dart 3.8)**. This matches `pubspec.lock`
  (`flutter >=3.32.0`, `dart >=3.8.0`). The revision in `.metadata` (3.13.9 /
  Dart 3.1.5) is **stale and cannot resolve dependencies** — `flutter_gemini`
  requires Dart ≥3.2. Flutter is installed at `~/flutter` and is on `PATH` via
  `~/.bashrc`.
- `lib/generated/` (Freezed/Hive/json codegen) is **git-ignored and required**.
  Run `make gen` / `dart run build_runner build --delete-conflicting-outputs`
  before `flutter analyze`, `flutter test`, or any build, or you'll get missing
  `part` file errors. The startup update script handles this automatically.
- `assets/.env` is **git-ignored and required** by `flutter run`/`flutter build`
  (it's a declared asset in `pubspec.yaml`). The update script creates a stub
  with empty API keys and `DISABLE_REALTIME_LOCATIONS=true`. Fill in real
  `GEMINI_API_KEY` / Firebase / Maps keys for full functionality.

### Running the app — important limitation
- The app **targets iOS/macOS** and **cannot run as a GUI on this Linux VM**:
  - `lib/firebase_options.dart` only configures iOS and macOS;
    `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` on
    web/linux/windows (and Android falls through to the same throw, despite
    `android/app/google-services.json` existing). `main()` calls
    `Firebase.initializeApp` before `runApp`, so nothing renders on those
    platforms.
  - The **web** target additionally fails to *compile*: the pinned
    `firebase_storage_web 3.6.22` is incompatible with the Flutter 3.32 web
    compiler (missing `PromiseJsImpl`/`jsify`/`handleThenable`).
  - To run the real app, use a **Mac with Xcode + iOS simulator** (see README)
    with valid Firebase/Maps/Gemini keys in `assets/.env`.
- On Linux the practical dev loop is: `make gen` (codegen) →
  `flutter analyze` (lint) → `flutter test`. Core, Firebase-free logic can be
  exercised headlessly — e.g. `ItineraryCubit.loadDemoItinerary()` loads
  `assets/demo/*.json` and parses it via the generated models. See
  `test/itinerary_demo_smoke_test.dart` and `test/itinerary_card_golden_test.dart`
  (the latter renders real UI widgets to a PNG via `--update-goldens`).

### Pre-existing issues (not environment problems)
- `test/widget_test.dart` is the default Flutter **counter** template test and
  **fails** — the app has no counter. The README roadmap lists "Test suite" as a
  TODO.
- `pubspec.yaml` declares `assets/icons/` which doesn't exist; this prints a
  non-fatal `unable to find directory entry` message during test/run and an
  analyze warning.
