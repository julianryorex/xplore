# Current State (as of product backlog creation)

Snapshot of what exists in `lib/` vs. what product assumes. Update this doc when major foundations land.

## Shipped & working (demo / single-user)

| Capability | Status | Notes |
|------------|--------|-------|
| Itinerary UI | ✅ Demo | `ItineraryCubit.loadDemoItinerary()` reads `assets/demo/itinerary.json` |
| Day overview + location detail | ✅ | `ItineraryOverviewPage`, `ItineraryFocusPage` |
| Google Map + neon style | ✅ | `MapCanvas`, `assets/maps/GoogleMapNeon.json` |
| Live location sync | ✅ Demo | Firebase RTDB at `locations/{itineraryId}`; interval configurable via `.env` |
| Avatar map markers | ✅ | Profile photo → widget → PNG → Hive + Storage |
| Gallery pick / upload / zoom | ✅ Partial | Optimistic UI; compression disabled on iOS 26 SDK |
| Profile photo | ✅ Local | Saved to app documents; not synced to Firebase Auth profile |
| Bottom nav | ✅ | Home, Map, Gallery routes |

## Hardcoded / prototype assumptions

These block real users and monetization:

```dart
// lib/constants/constants.dart
const itineraryId = 'ph4kd';
const userId = '7d125e54-9de9-4a5c-bb15-29efacda4f9a';
```

Also hardcoded:

- Gallery Storage path: `gallery/ph4kd/` in `GalleryCubit.uploadImage`
- Demo itinerary lookup by key `ph4kd` in `ItineraryCubit`
- Profile name: `'Julian Rechsteiner'` in `ProfileCubit`
- Notifications button on home: `onTapCallback: () => log('tapped')` — no-op

## Stubbed / not wired

| Item | Evidence |
|------|----------|
| Onboarding | `Paths.onboarding` → empty `Container()` |
| Authentication | No Firebase Auth; README roadmap item |
| Multi-trip | Single demo itinerary only |
| Gemini AI in UI | Dependency in `pubspec.yaml`; no cubit/screen integration |
| Gallery cloud fetch | `GalleryRepository` TODO: GCP fetch; cache-only on new device |
| Push notifications | UI affordance only |
| Background location | TODOs in `LocationCubit` |
| Android / web runtime | iOS/macOS Firebase config only |

## Data model readiness

`ItineraryModel` already includes fields useful for production:

- `id`, `invitees`, `daily_plans`, `last_updated`, `pins`

Location and gallery layers need the same **trip-scoped IDs** from a shared `TripCubit` or auth/session layer rather than constants.

## Engineering debt affecting product timeline

- Test suite incomplete (`test/widget_test.dart` is template counter test)
- No CI/CD
- `assets/icons/` declared but missing (non-fatal warning)

See [BACKLOG.md](./BACKLOG.md) for prioritized work to close these gaps.
