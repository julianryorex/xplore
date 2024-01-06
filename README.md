# Xplore

A Flutter group-travel companion app featuring shared day-by-day itineraries, real-time location tracking on a custom-styled Google Map, and a collaborative trip photo gallery — powered by Firebase and experimenting with Gemini AI for itinerary generation.

---

## Features

**Shared Itineraries**
Browse day-by-day travel plans with a horizontal card carousel. Drill into a day overview with a visual checklist timeline, then into individual location details. Demo data covers a multi-stop Tokyo itinerary (Tsukiji Market, Senso-ji, Tokyo SkyTree, etc.).

**Real-Time Group Map**
Every trip member's live GPS position is synced to Firebase Realtime Database and rendered on a neon-dark-styled Google Map. Markers use each member's profile photo (rendered widget → PNG bitmap → cached in Hive & Firebase Storage). Stale locations (>10 min) fade in opacity for visual feedback.

**Collaborative Photo Gallery**
Multi-image picker with on-device compression for fast thumbnails. Metadata and thumbnails are cached locally in Hive while full-resolution images upload to Firebase Storage asynchronously. Optimistic UI shows upload progress states. Full-screen gallery view with pinch-to-zoom via `photo_view`.

**AI Itinerary Generation (Experimental)**
Google Gemini integration that generates structured daily travel plans from a prompt. Output is saved as JSON — groundwork for AI-assisted trip planning in future iterations.

---

## Architecture

```
lib/
├── main.dart                  # Firebase/Hive/Gemini init, MultiBlocProvider root
├── routes.dart                # Named routes with FadePageRoute transitions
├── constants/                 # Colors, theme (dark + Poppins), extensions
├── core/                      # Shared UI primitives (navbar, header, icon button, avatar marker)
├── features/
│   ├── gallery/               # Cubit, Freezed models, Hive repository, picker/grid/zoom UI
│   ├── itinerary/             # Cubit, Freezed models, card & tile widgets
│   ├── location/              # Cubit + models for GPS sync
│   ├── map/                   # Cubit + marker rendering service
│   ├── nav/                   # Bottom nav cubit
│   └── profile/               # Cubit + state for profile photo
├── screens/                   # Page-level widgets (home, map, gallery, itinerary, profile, error)
└── utilities/                 # Screen helpers, structured logging, JSON asset loader
```

**Key patterns:**
- **Feature-first modular structure** — each domain owns its bloc, models, and presentation layer
- **Cubit-based state management** (flutter_bloc) — 6 cubits registered at the app root
- **Immutable models** via Freezed with json_serializable codegen
- **Offline-first data layer** — Hive for local caching, Firebase for cloud sync
- **Repository pattern** for gallery (Hive abstraction); other features interact with Firebase directly from cubits

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart >=3.1.5) |
| State Management | flutter_bloc / Cubit |
| Data Modeling | Freezed + json_serializable |
| Local Storage | Hive |
| Backend | Firebase (Realtime Database, Storage) |
| Maps | Google Maps Flutter + Geolocator |
| AI | Google Gemini (flutter_gemini) |
| Media | image_picker, flutter_image_compress, photo_view |
| Tooling | build_runner, flutter_lints, Makefile automation |

---

## Getting Started

### Prerequisites

- Flutter SDK (>=3.1.5)
- Xcode (for iOS builds)
- A Firebase project with Realtime Database and Storage enabled
- Google Maps API key
- (Optional) Google Gemini API key

### Setup

```bash
# Clone the repo
git clone https://github.com/<your-username>/xplore.git
cd xplore

# Install dependencies
make get

# Create your environment file
cp assets/.env.example assets/.env
# Fill in GEMINI_API_KEY, DISABLE_REALTIME_LOCATIONS, etc.

# Generate Freezed/Hive/JSON code
make gen

# Run on iOS simulator
flutter run
```

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make get` | Install Flutter dependencies |
| `make gen` | Run build_runner (Freezed, json_serializable, Hive adapters) |
| `make format` | Apply dart fixes and format (120 char line width) |
| `make check-format` | CI-style format check |
| `make build-ios` | Build iOS release |
| `make clean` | Clean build artifacts and generated code |
| `make reboot` | Full rebuild: clean → get → gen → build-ios |

---

## Roadmap

- [ ] Authentication and multi-user support
- [ ] Onboarding flow
- [ ] Multi-trip / itinerary management
- [ ] Wire AI-generated itineraries into the main UI flow
- [ ] Android platform support
- [ ] Test suite (unit, widget, integration)
- [ ] CI/CD pipeline

---

## License

This project is not currently published under a license. All rights reserved.
