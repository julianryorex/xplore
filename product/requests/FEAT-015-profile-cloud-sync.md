# FEAT-015: Profile Cloud Sync

| Field | Value |
|-------|-------|
| **ID** | FEAT-015 |
| **Priority** | P1 |
| **Status** | `backlog` |
| **Revenue impact** | retention |
| **Effort** | L (was M — grew with cross-device read model + handle) |
| **Owner** | — |

## Problem

The signed-in user's profile only half-exists in the cloud. `AuthService._upsertUserProfile`
already writes a `users/{uid}` doc on every sign-in (`uid`, `displayName`, `email`,
`photoUrl`, `providers`, `createdAt`, `lastSeenAt`), but the **app never reads it back**:

- `ProfileCubit` still seeds `name: 'Julian Rechsteiner'` and only ever loads the avatar
  from a local `profile_picture.png` (`lib/features/profile/bloc/profile_cubit.dart`).
- The Edit Profile page's **Save Changes** button is a no-op (`onPressed: () {}`), the
  name field is read-only, and the `@handle` is **faked** at render time by slugging the
  display name (`lib/screens/profile_page.dart`).
- `changeProfilePicture` saves the photo locally and regenerates the *map-marker PNG*,
  but never uploads the source avatar to Storage and never writes `photoUrl` to Firestore.
- Peers on other devices can't show your photo on the map: `MarkerService.uploadMarkerIcon`
  uploads the marker PNG to `markers/{id}/marker` but **discards the download URL**, and
  `MapCubit.updateUserMarkers` only reads markers from **local Hive** — so trip-mates fall
  back to the default red pin (see FEAT-046 #4).

Net: a returning user, a second device, or a reinstall shows a hardcoded name, a missing
avatar, and a generic pin — directly undercutting the "see your group on the map" promise.

## Proposed solution

Make `users/{uid}` the source of truth for the profile and wire the full read **and**
write path, mirroring the offline-first cloud pattern already used by `ItineraryCubit`
(Hive cache → live Firestore listener via a thin service; cubits never import cubits).

1. **Account creation (seed real data).** Extend `AuthService._upsertUserProfile` so a new
   user's profile is never empty: keep `displayName`/`email`/`photoUrl` from the provider,
   and seed an editable `username` (handle) generated from the display name with a
   uniqueness-safe suffix. Apple returns no photo, so leave `photoUrl` null and render the
   initial-letter fallback already in the UI.
2. **Hydration on login & app open.** Introduce a `ProfileService` (read/watch/write
   `users/{uid}`) and `ProfileRepository` (Hive cache). `ProfileCubit`, created behind the
   auth gate, loads the cached profile first then attaches a live `users/{uid}` snapshot
   listener — covering both fresh login and returning-session app-open, online or offline.
   Drop the hardcoded name.
3. **Editable profile (write path).** Wire Save Changes: editing the **handle** writes to
   `users/{uid}`; changing the photo uploads the **source avatar** to Storage
   (`avatars/{uid}`), stores its `photoUrl` in Firestore, then regenerates and uploads the
   marker PNG and records its URL. Update the local Hive cache optimistically. The
   **display name is read-only** — it stays sourced from the auth provider (Apple/Google)
   and is shown but never edited in-app.
4. **Cross-device avatar read.** Expose the minimal public fields peers need
   (`displayName`, `username`, `photoUrl`, `markerUrl`) so `MapCubit` can fetch and cache a
   trip-mate's marker by URL instead of only reading local Hive. (Pairs with FEAT-046.)

### Handle & avatar: auto-seed vs. let the user choose (recommendation)

**Recommendation: do both — auto-seed sensible defaults at account creation, then offer an
*optional* "Set up your profile" step in onboarding (FEAT-005).** Rationale:

- Auto-seeding guarantees nothing is ever hardcoded/empty (name from provider, photo from
  provider when present, a generated unique handle), so the app and the map look right the
  moment a user lands — even if they skip customization.
- An *optional, skippable* onboarding step lets users personalize photo + handle without
  adding a blocking gate that would hurt FEAT-005's >70% completion target. Anything not
  set in onboarding remains editable later on the Edit Profile page.

**Handles are globally unique (decided).** Uniqueness is enforced by a claim registry where
the handle value *is* the document ID — `usernames/{usernameLower} → { uid }` — so "is it
taken?" reduces to "does the doc exist?". Claims/changes run in a Firestore
`runTransaction` (read the doc; abort if it exists and isn't yours; otherwise create it,
release your old one, and update `users/{uid}` + `publicProfiles/{uid}` atomically), with
security rules that only allow creating a free handle mapped to your own uid and deleting
your own. **For this pass the only requirement is auto-generating a unique handle** (first
name + short hash, retry on collision) so every user has a valid unique value with no
friction; this is best-effort and **never blocks sign-in**. Existing users are backfilled
on next sign-in. **Letting users choose/edit their handle is part of the onboarding flow
(FEAT-005)** — it reuses the same claim transaction plus a live availability check.

## User stories

- As a returning user (or on a new device / after reinstall), I want my real name and photo
  to load from the cloud, so I never see a placeholder identity.
- As a trip member, I want my photo to appear on my teammates' maps automatically, so the
  group can tell who's where at a glance.
- As a new user, I want to optionally set my photo and handle during onboarding (and change
  them later), so my profile feels like mine without forcing extra steps.

## Acceptance criteria

- [ ] On account creation, `users/{uid}` is seeded with `displayName`, `email`, `photoUrl`
      (when the provider supplies one), `providers`, and a generated `username` — no empty
      or hardcoded identity fields.
- [ ] `ProfileCubit` hydrates from `users/{uid}` on login **and** on returning-session app
      open, cache-first (Hive) then a live Firestore listener; the `'Julian Rechsteiner'`
      default is removed.
- [ ] Editable **handle** on the Edit Profile page (display name stays read-only, sourced
      from the auth provider); Save Changes persists to `users/{uid}` (no longer a no-op)
      and updates the local cache.
- [ ] Changing the avatar uploads the source image to Storage (`avatars/{uid}`), writes
      `photoUrl` to `users/{uid}`, and regenerates + uploads the marker, recording its URL.
- [ ] A trip-mate's avatar marker is fetched by URL and cached when it isn't already in
      local Hive, so peers render real avatars instead of the default pin (with FEAT-046).
- [ ] Firestore rules expose only the public profile fields (`displayName`, `username`,
      `photoUrl`, `markerUrl`) to other signed-in trip members while keeping `email` and
      other PII owner-only; rules pass the security-rules auditor.
- [ ] Handles are **globally unique** via a `usernames/{handleLower}` registry claimed
      transactionally, enforced by security rules, with **auto-generated unique handles
      (e.g. `firstname-<hash>`) at account creation** and lazy backfill for existing users.
      Letting users **pick/edit** a handle (live availability check) is part of the
      onboarding flow (FEAT-005), not the Edit Profile page in this pass.

## Success metrics

- Profile loads correct name + avatar on a second device / after reinstall in 100% of test
  runs (no placeholder identity).
- Share of map markers rendering a real avatar (not the default pin) for users who have a
  photo set.
- Edit Profile Save success rate ~100% (event: `profile_saved`).

## Dependencies

- FEAT-001 (auth + `users/{uid}` doc) — **done**.
- FEAT-005 (onboarding) — optional profile-setup step lives here; keep the two in sync.
- FEAT-046 (avatar map-marker pipeline) — provides bounded source image + robust marker
  rendering + the cross-device download this feature reads.
- Infra: Firestore + Storage **rules deploy** (the public-profile read rule and
  `avatars/{uid}` Storage path must ship; rules deploy is still pending per CURRENT_STATE).

## Decisions (locked)

- **Handles are globally unique** — registry + transaction + rules, core scope (effort L).
- **Peer reads** via a denormalized `publicProfiles/{uid}` mirror (keeps `email`/PII
  owner-only, avoids cross-doc trip lookups in rules).
- **Hive is a read-through cache:** the `users/{uid}` snapshot listener is the only writer,
  writes go to Firestore and echo back, Firestore offline persistence enabled.

## Open questions

- Public-profile read model: relax `users/{uid}` read to shared-trip members, or
  denormalize a `publicProfiles/{uid}` doc with only the four public fields? (Leaning
  denormalized — simpler/safer rules, keeps `email` private, no cross-doc trip lookups.)
- Avatar variants: one bounded master (FEAT-046 Option A) is enough for both the page and
  the marker; do we also need a separate thumbnail? (Default: master-only.)
- Migration: existing users have no `username` — generate lazily on next sign-in vs. a
  one-off backfill.

## Related code

- `lib/features/auth/services/auth_service.dart` — `_upsertUserProfile` (seed `username`).
- `lib/features/profile/bloc/profile_cubit.dart` / `profile_state.dart` — hydrate from
  cloud, add handle/photoUrl, write path; remove hardcoded name + local-only avatar load.
- `lib/screens/profile_page.dart` — wire Save Changes; editable name + handle; stop faking
  `@handle`.
- `lib/features/map/services/marker_service.dart` — persist the marker `downloadURL`.
- `lib/features/map/bloc/map_cubit.dart` — `updateUserMarkers` fetch-by-URL fallback.
- `lib/features/itinerary/bloc/itinerary_cubit.dart` — reference offline-first hydration
  pattern (cache → live listener via service).
- `infra/rules/firestore.rules` — `users/{uid}` is owner-only today (line ~163); add the
  public-profile read rule. `infra/rules/storage.rules` — add `avatars/{uid}`.

## Data model

```jsonc
// Firestore: users/{uid}  (owner read/write; PII stays here)
{
  "uid": "string",
  "displayName": "string",      // editable; seeded from provider
  "email": "string|null",       // owner-only, never exposed to peers
  "photoUrl": "string|null",    // Storage avatars/{uid} download URL (or provider URL)
  "username": "string",         // editable handle, seeded at creation
  "usernameLower": "string",    // lookup/uniqueness key (if strict handles)
  "markerUrl": "string|null",   // derived marker PNG URL for peers
  "providers": ["google"],
  "createdAt": "timestamp",
  "lastSeenAt": "timestamp"
}

// Firestore: publicProfiles/{uid}  (signed-in read; peers render name/handle/avatar)
// { displayName, username, photoUrl, markerUrl }

// Firestore: usernames/{usernameLower} -> { uid }  (unique-handle claim registry)
// Claimed in a runTransaction; rules: create only if absent & maps to own uid, delete own.
```

## Notes / history

- 2025-06-22: Created.
- 2026-06-26: Revised into a build-ready spec after code audit. Corrected the premise
  (the `users/{uid}` doc already exists from FEAT-001; the gap is the read/hydration +
  write paths, not the doc). Added account-creation seeding, login/app-open hydration,
  editable handle, cross-device avatar read, and a public-profile rules model. Recommended
  auto-seed + optional onboarding customization; flagged strict-handle uniqueness as the
  open scope decision (M→L). Wired the onboarding tie-in into FEAT-005.
