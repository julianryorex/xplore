# Current State (as of 2026-06-24, EOD)

Snapshot of what exists in `lib/` vs. what product assumes. Update this doc when major foundations land.

## Shipped & working

| Capability | Status | Notes |
|------------|--------|-------|
| User authentication | ✅ | Google Sign-In + `AuthCubit` hard gate; Apple deferred ([FEAT-001](./requests/done/FEAT-001-user-authentication.md), PR #73) |
| Trip entity (foundation) | ✅ Partial | `TripCubit`, create-trip sheet, `activeTripId` plumbing ([FEAT-002](./requests/done/FEAT-002-trip-management.md), PR #79); multi-trip switcher UI deferred |
| Dynamic user/trip IDs | ✅ | Cubits read uid from auth and trip scope from `TripCubit` ([FEAT-004](./requests/done/FEAT-004-remove-hardcoded-ids.md), PR #76) |
| Itinerary cloud read path | ✅ Partial | `ItineraryCubit.loadForTrip(activeTripId)` listens to Firestore `itineraries/{tripId}`, Hive CE offline cache, lazy seed on missing doc ([FEAT-006](./requests/FEAT-006-itinerary-firebase-sync.md) read slice, PR #87); editing CRUD UI deferred |
| Itinerary UI | ✅ | Day carousel, overview, location detail; runtime data from cloud when a trip is active |
| Google Map + neon style | ✅ | `MapCanvas`, `assets/maps/GoogleMapNeon.json` |
| Live location sync | ✅ | Firebase RTDB at `locations/{tripId}`; interval configurable via `.env` |
| Avatar map markers | ✅ | Profile photo → widget → PNG → Hive CE + Storage |
| Gallery pick / upload / zoom | ✅ | Optimistic UI; pure-Dart thumbnail compression ([FEAT-043](./requests/done/FEAT-043-image-compression.md)) |
| Profile photo | ✅ Local | Saved to app documents; liquid-glass Edit Profile UI (PR #88); cloud sync is FEAT-015 |
| Notifications screen | ✅ UI shell | Home header routes to liquid-glass feed with sample data (PR #86); FCM / push delivery is FEAT-012 |
| Trip load error UX | ✅ | Liquid-glass error banner when `TripCubit` fails (PR #85) |
| App icon | ✅ | iOS + macOS launcher icons from `assets/branding/app_icon.jpg` (PR #78) |
| Bottom nav | ✅ | Home and Map live in a persistent tab shell; Gallery opens as a Home drill-down |
| Test infrastructure | ✅ Partial | Golden + cubit unit tests, test tree aligned with `lib/` (PR #80, #84); full suite still FEAT-036 |

## Remaining prototype assumptions

These still block real multi-user group travel:

```dart
// lib/constants/constants.dart — demo fallback only
const itineraryId = 'ph4kd';
```

`location` and `gallery` cubits still use `_activeTripId ?? itineraryId` until FEAT-014
tightens gallery storage paths. Itinerary production reads no longer depend on demo JSON
at runtime — `loadDemoItinerary()` is test/golden-only.

Also outstanding:

- New trips seed an **empty** cloud itinerary (`daily_plans: []`); Tokyo demo content not copied on create → FEAT-006 follow-up
- Itinerary **editing CRUD** not built; gated on FEAT-024 organizer roles → FEAT-006 follow-up
- Mock onboarding placeholder only → **FEAT-005**
- No trip invites / deep links → **FEAT-003**
- Gallery uploads not fully trip-scoped in Storage rules → **FEAT-014**
- Profile name / avatar not synced to cloud → **FEAT-015**
- Push notifications not wired (screen exists; no FCM) → **FEAT-012**
- GitHub auth issues still Apple-titled despite Google shipping → reconcile via Issue Filer

## Stubbed / not wired

| Item | Evidence |
|------|----------|
| Itinerary editing CRUD | Read path only; organizer UI deferred (FEAT-006 / FEAT-024) |
| Multi-trip switcher | Create-trip works; list/switch UI deferred (FEAT-002 gap) |
| Gemini AI in UI | Dependency in `pubspec.yaml`; no cubit/screen integration |
| Gallery cloud fetch | `GalleryRepository` TODO: GCP fetch; cache-only on new device |
| Push notifications (FCM) | `NotificationsPage` uses local sample data; no backend |
| Background location | TODOs in `LocationCubit` |
| Android / web runtime | iOS/macOS Firebase config only |

## Data model readiness

`ItineraryModel` and `TripModel` include fields useful for production. Itinerary data
lives at `itineraries/{tripId}` in Firestore. Location and gallery layers consume
`TripCubit.activeTripId` with the `ph4kd` demo fallback for late subscribers and tests.

## Engineering debt affecting product timeline

- Test suite incomplete — infrastructure and itinerary cubit coverage landed (PR #80, #87); more P0 cubit coverage in FEAT-036
- No CI/CD
- `assets/icons/` declared but missing (non-fatal warning)
- GitHub issue queue stale for auth (epic #35 / subs #27, #34 still Apple-titled)

See [BACKLOG.md](./BACKLOG.md) for prioritized work to close these gaps.
