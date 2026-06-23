# AGENTS.md

## Cursor Cloud specific instructions

Xplore is a Flutter group-travel app (state via flutter_bloc/Cubit, Freezed +
json_serializable models, Hive local cache, Firebase backend, Google Maps,
Gemini). See `README.md` and the `Makefile` for the canonical commands
(`make get`, `make gen`, `make format`, `make check-format`).

**Product backlog:** Before starting net-new features, read `product/BACKLOG.md`
(prioritized P0–P4 requests with acceptance criteria and code pointers). Add new
requests via `product/requests/_TEMPLATE.md`.

**GitHub issues:** Issues are the execution queue; `product/requests/` stays the
spec source of truth. Do **not** create GitHub issues directly — emit an
`issue-proposal` block (see `.github/ISSUE_FILING.md`) and let the Issue Filer
agent file it. Exception: the Issue Filer automation itself.

**Pull requests:** When opening a PR for work tied to a GitHub issue, the PR
body **must** include a `Closes #N` line (or `Fixes #N` / `Resolves #N`) for
each issue the PR fully completes — place it in a **Linked issues** section near
the top (see `.github/pull_request_template.md`). GitHub only auto-closes issues
when one of those keywords appears in the PR description; omitting it leaves
completed work looking stale in the issue queue. If the PR only partially
addresses an issue, use `Related: #N` instead — never `Closes`. When starting
from a FEAT spec, run `gh issue list --state open --limit 100` and link the
matching epic or sub-issue before `gh pr create`.

### Toolchain / setup notes (non-obvious)
- Use **FVM-pinned Flutter 3.44.0 (Dart 3.12)**. This matches `.fvmrc`,
  `pubspec.yaml`, and `pubspec.lock` (`flutter >=3.44.0`, `dart >=3.12.0`).
  The revision in `.metadata` (3.13.9 / Dart 3.1.5) is **stale** and won't
  resolve deps. Run `fvm install` and `fvm use 3.44.0 --skip-pub-get` once,
  then use `make` targets or `fvm flutter` / `fvm dart` for ad hoc commands.
- `lib/generated/` (Freezed/json codegen) is **git-ignored and required**.
  Run `make gen` / `fvm dart run build_runner build` before
  `fvm flutter analyze`, `fvm flutter test`, or any build, or you'll get missing
  `part` file errors. The
  startup update script handles this automatically. Note: `hive_generator` was
  removed — Hive `TypeAdapter`s are now hand-written in
  `lib/features/gallery/models/image_models_adapters.dart`. Also, build_runner
  ≥2.15 ignores the old `--delete-conflicting-outputs` flag (harmless no-op).
- `assets/.env` is **git-ignored and required** by `fvm flutter run` /
  `fvm flutter build`
  (it's a declared asset in `pubspec.yaml`). The update script creates a stub
  with empty API keys and `DISABLE_REALTIME_LOCATIONS=true`. Fill in real
  `GEMINI_API_KEY` / Firebase / Maps keys for full functionality.

### Running the app — important limitation
- The app **targets iOS/macOS** and **cannot run as a GUI on this Linux VM**.
  The web target now *compiles* (`fvm flutter build web` succeeds after the
  Firebase v4/v13 upgrade), but it **crashes at runtime**:
  `lib/firebase_options.dart` only configures iOS and macOS, and on web/Linux
  `defaultTargetPlatform` resolves to `linux`, so
  `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` and
  `main()` dies before `runApp` (blank page; see the browser console).
  `main.dart`'s `initFirebase` only catches `duplicate-app`, not this. The same
  throw blocks linux/windows/Android.
- To run the real app, use a **Mac with Xcode + iOS simulator** (see README)
  with valid Firebase/Maps/Gemini keys in `assets/.env`. Note `flutter_image_compress`
 was removed (the iOS 26 SDK dropped the AssetsLibrary framework it relied on);
 gallery **thumbnails** are now compressed with the pure-Dart `image` package
 (`lib/features/gallery/services/image_compressor.dart`), while the
 **full-resolution original is still uploaded** to Storage for full-detail viewing.
- On Linux the practical dev loop is: `make gen` (codegen) →
  `fvm flutter analyze` (lint) → `fvm flutter test`. Core, Firebase-free logic
  can be exercised headlessly — e.g. `ItineraryCubit.loadDemoItinerary()` loads
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
