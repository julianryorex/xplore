# Current State (as of 2026-06-24)

Snapshot of what exists in `lib/` vs. what product assumes. Update this doc when major foundations land.

## Shipped & working

| Capability | Status | Notes |
|------------|--------|-------|
| User authentication | ✅ | Google Sign-In + `AuthCubit` hard gate; Apple deferred ([FEAT-001](./requests/done/FEAT-001-user-authentication.md), PR #73) |
| Trip entity (foundation) | ✅ Partial | `TripCubit`, create-trip sheet, `activeTripId` plumbing ([FEAT-002](./requests/done/FEAT-002-trip-management.md), PR #79); switcher UI deferred |
| Dynamic user/trip IDs | ✅ | Cubits read uid from auth and trip scope from `TripCubit` ([FEAT-004](./requests/done/FEAT-004-remove-hardcoded-ids.md), PR #76) |
| Itinerary UI | ✅ Demo | `ItineraryCubit.loadDemoItinerary()` reads `assets/demo/itinerary.json` — cloud sync is FEAT-006 |
| Day overview + location detail | ✅ | `ItineraryOverviewPage`, `ItineraryFocusPage` |
| Google Map + neon style | ✅ | `MapCanvas`, `assets/maps/GoogleMapNeon.json` |
| Live location sync | ✅ | Firebase RTDB at `locations/{tripId}`; interval configurable via `.env` |
| Avatar map markers | ✅ | Profile photo → widget → PNG → Hive + Storage |
| Gallery pick / upload / zoom | ✅ | Optimistic UI; pure-Dart thumbnail compression ([FEAT-043](./requests/done/FEAT-043-image-compression.md)) |
| Profile photo | ✅ Local | Saved to app documents; cloud sync is FEAT-015 |
| Bottom nav | ✅ | Home, Map, Gallery routes |
| Test infrastructure | ✅ Partial | Golden + cubit unit tests (PR #80); full suite still FEAT-036 |

## Remaining prototype assumptions

These still block real multi-user group travel:

```dart
// lib/constants/constants.dart — demo fallback only
const itineraryId = 'ph4kd';
```

Also outstanding:

- `ItineraryCubit` loads demo JSON keyed by `itineraryId` regardless of active trip → **FEAT-006**
- Mock onboarding placeholder only → **FEAT-005**
- No trip invites / deep links → **FEAT-003**
- Notifications button on home: `onTapCallback: () => log('tapped')` — no-op
- Profile name not synced to cloud → **FEAT-015**

## Stubbed / not wired

| Item | Evidence |
|------|----------|
| Production itinerary sync | Demo JSON only; FEAT-006 |
| Multi-trip switcher | Create-trip works; list/switch UI deferred |
| Gemini AI in UI | Dependency in `pubspec.yaml`; no cubit/screen integration |
| Gallery cloud fetch | `GalleryRepository` TODO: GCP fetch; cache-only on new device |
| Push notifications | UI affordance only |
| Background location | TODOs in `LocationCubit` |
| Android / web runtime | iOS/macOS Firebase config only |

## Data model readiness

`ItineraryModel` and `TripModel` include fields useful for production. Location and gallery layers consume `TripCubit.activeTripId` with a demo fallback until FEAT-006 fully replaces itinerary demo data.

## Engineering debt affecting product timeline

- Test suite incomplete — infrastructure landed (PR #80); counter template test removed; more P0 cubit coverage in FEAT-036
- No CI/CD
- `assets/icons/` declared but missing (non-fatal warning)

See [BACKLOG.md](./BACKLOG.md) for prioritized work to close these gaps.
