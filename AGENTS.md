# AGENTS.md

## Cursor Cloud specific instructions

Xplore is a Flutter group-travel app (state via flutter_bloc/Cubit, Freezed +
json_serializable models, Hive local cache, Firebase backend, Google Maps,
Gemini). See `README.md` and the `Makefile` for the canonical commands
(`make get`, `make gen`, `make format`, `make check-format`).

### Toolchain / setup notes (non-obvious)
- Use **Flutter 3.44.x (Dart 3.12)**. This matches `pubspec.lock`
  (`flutter >=3.44.0`, `dart >=3.12.0`). The revision in `.metadata` (3.13.9 /
  Dart 3.1.5) is **stale** and won't resolve deps. Flutter is installed at
  `~/flutter` and is on `PATH` via `~/.bashrc`.
- `lib/generated/` (Freezed/json codegen) is **git-ignored and required**.
  Run `make gen` / `dart run build_runner build` before `flutter analyze`,
  `flutter test`, or any build, or you'll get missing `part` file errors. The
  startup update script handles this automatically. Note: `hive_generator` was
  removed — Hive `TypeAdapter`s are now hand-written in
  `lib/features/gallery/models/image_models_adapters.dart`. Also, build_runner
  ≥2.15 ignores the old `--delete-conflicting-outputs` flag (harmless no-op).
- `assets/.env` is **git-ignored and required** by `flutter run`/`flutter build`
  (it's a declared asset in `pubspec.yaml`). The update script creates a stub
  with empty API keys and `DISABLE_REALTIME_LOCATIONS=true`. Fill in real
  `GEMINI_API_KEY` / Firebase / Maps keys for full functionality.

### Running the app — important limitation
- The app **targets iOS/macOS** and **cannot run as a GUI on this Linux VM**.
  The web target now *compiles* (`flutter build web` succeeds after the Firebase
  v4/v13 upgrade), but it **crashes at runtime**: `lib/firebase_options.dart`
  only configures iOS and macOS, and on web/Linux `defaultTargetPlatform`
  resolves to `linux`, so `DefaultFirebaseOptions.currentPlatform` throws
  `UnsupportedError` and `main()` dies before `runApp` (blank page; see the
  browser console). `main.dart`'s `initFirebase` only catches `duplicate-app`,
  not this. The same throw blocks linux/windows/Android.
- To run the real app, use a **Mac with Xcode + iOS simulator** (see README)
  with valid Firebase/Maps/Gemini keys in `assets/.env`. Note `pubspec.yaml`
  currently disables `flutter_image_compress` (the iOS 26 SDK dropped the
  AssetsLibrary framework it relies on); gallery uploads fall back to
  uncompressed images.
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
  non-fatal `unable to find directory entry` message during test/run/build and
  an analyze warning.
