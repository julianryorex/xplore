<p align="center">
  <img src="assets/branding/app_icon.jpg" alt="Xplore app icon" width="128" />
</p>

# Xplore

A Flutter group-travel companion app. Friends on the same trip share a
day-by-day itinerary, see each other's live location on a custom-styled map, and
build a collaborative photo gallery — backed by Firebase, with an experimental
Google Gemini integration for AI-generated itineraries.

> iOS-first. Built with Flutter + flutter_bloc, Freezed models, an offline-first
> Hive CE cache, and Firebase.

## Features

- **Shared itineraries** — day-by-day plans in a card carousel, drilling into a
  checklist timeline and per-location detail.
- **Real-time group map** — each member's live location on a neon-dark Google
  Map, with profile-photo markers that fade as they go stale.
- **Collaborative photo gallery** — multi-image picker with optimistic upload,
  on-device thumbnail compression, local caching, and pinch-to-zoom viewing.
- **AI itinerary generation (experimental)** — Gemini turns a prompt into a
  structured daily plan.

## Tech stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.44 / Dart 3.12 (via FVM) |
| State | flutter_bloc / Cubit |
| Models | Freezed + json_serializable |
| Local storage | Hive CE |
| Backend | Firebase (Realtime Database, Storage) |
| Maps | Google Maps + Geolocator |
| AI | Google Gemini |

## Getting started

You can build and launch the UI without any backend setup. Sign-in and cloud
features simply fail until real credentials are provided.

```bash
git clone https://github.com/<your-username>/xplore.git
cd xplore

# Install the pinned Flutter SDK (from .fvmrc)
fvm install
fvm use 3.44.0 --skip-pub-get

make get                          # dependencies
cp assets/.env.example assets/.env  # required asset (works with empty keys)
make gen                          # code generation (Freezed / JSON)

fvm flutter run                   # iOS simulator
```

**Prerequisites:** [FVM](https://fvm.app) and Xcode (for iOS).

For the full architecture, Makefile commands, environment variables, CI notes,
and how to wire up real Firebase / Maps / Gemini, see
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md). Code conventions live in
[`docs/PATTERNS.md`](docs/PATTERNS.md), and the prioritized product roadmap is in
[`product/BACKLOG.md`](product/BACKLOG.md).

## License

Not currently published under a license. All rights reserved.
