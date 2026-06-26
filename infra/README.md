# Xplore Firebase infra (Terraform)

Infrastructure-as-code for the Xplore backend on the existing Firebase/GCP
project **`xplore-a7012`**. This is **Phase 1** of FEAT-001 (see
`.cursor/plans/`): it imports the existing Firestore/Datastore database, is the
single source of truth for security rules (Firestore + RTDB + Storage), and scaffolds the Apple
sign-in provider.

> We never manage the GCP project resource itself (no create/destroy). Existing
> resources are **imported**, not recreated.

## What this provisions

| Service | Resource | Mode |
|---------|----------|------|
| Firebase | `google_firebase_project`, `google_firebase_apple_app` | import |
| Auth | `google_identity_platform_config` (base) + Google IdP (gated) + Apple IdP (gated) | create/scaffold |
| Firestore / Datastore | existing `(default)` database (`nam5`, `DATASTORE_MODE`) | import / protect |
| Firestore app DB | named `xplore-app` database (`us-east1`, `FIRESTORE_NATIVE`) + rules | create |
| Realtime DB | `google_firebase_database_instance` + RTDB rules (REST) | import + apply |
| Storage | `google_firebase_storage_bucket` + rules | import |
| APIs | `google_project_service` (firebase, identitytoolkit, firestore, ...) | enable |

Auth providers: **Google** (interim, enabled now) and **Apple** (scaffolded,
gated on credentials). Anonymous deferred per FEAT-001. Google was brought
forward ahead of Apple while Apple Developer enrollment is unavailable; the
design stays provider-agnostic so Apple drops in by filling its vars.

## Prerequisites

- **Blaze billing** enabled on `xplore-a7012` (confirmed).
- **Terraform >= 1.5** (installed: 1.15.6).
- **gcloud CLI** with user ADC (installed at `~/google-cloud-sdk`):
  ```bash
  gcloud auth login
  gcloud auth application-default login
  ```
  Do **not** run a global `set-quota-project` — the provider sets
  `billing_project` + `user_project_override` itself (keeps multi-project
  machines clean).
- For the **RTDB rules** step (`null_resource`): a working `gcloud` on PATH
  (the local-exec uses `gcloud auth print-access-token`).
- Account role: Owner (or Editor + Firebase Admin + Service Usage Admin).

## Quota/billing project

Scoped entirely in `providers.tf` via `user_project_override = true` and
`billing_project = var.project_id`. No global gcloud quota project is set.

## First run

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # optional; defaults target xplore-a7012
terraform init
terraform plan      # ALWAYS review before apply
```

### Import existing resources (one-time, non-destructive)

Run these after `init` and before the first `apply`, so Terraform adopts the
existing resources instead of trying to create duplicates:

```bash
terraform import module.firebase.google_firebase_project.default projects/xplore-a7012
terraform import module.firebase.google_firebase_apple_app.apple 1:700905798457:ios:b3762811940cfb83c446e8
terraform import module.firestore.google_firestore_database.default 'projects/xplore-a7012/databases/(default)'
terraform import module.database.google_firebase_database_instance.default xplore-a7012/us-central1/xplore-a7012-default-rtdb
terraform import module.storage.google_firebase_storage_bucket.default xplore-a7012/xplore-a7012.appspot.com
# Identity Platform config, only if it already exists on the project:
terraform import module.auth.google_identity_platform_config.default xplore-a7012
```

> Verify the RTDB region in the import path. The default instance is usually in
> `us-central1`; check the Firebase console (Realtime Database) if the import
> errors, and adjust the region segment.

The default Firestore database already exists in this project as
`DATASTORE_MODE` in `nam5`; it is imported and must not be replaced. This keeps
Terraform aligned with current project state.

The Flutter app uses Firebase client SDK semantics, so it needs Firestore Native
mode. Terraform creates a separate named Native database:

```text
xplore-app
```

Phase 2 app code should use:

```dart
FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'xplore-app',
);
```

### Apply

```bash
terraform plan -out tfplan
terraform apply tfplan
```

## Google sign-in (interim provider)

Google is enabled ahead of Apple. Terraform owns the Identity Platform
`google.com` IdP config, but **Terraform cannot create the OAuth web client
itself** — that credential is created out-of-band and injected, the same way
Apple's `.p8` is.

1. Create the OAuth client (one-time):
   - Easiest: in the **Firebase Console > Authentication > Sign-in method**,
     enable **Google**. Firebase auto-creates a "Web client (auto created by
     Google Service)" OAuth 2.0 credential.
   - Or in **GCP Console > APIs & Services > Credentials**, create an OAuth 2.0
     Client ID of type **Web application**.
2. Copy the **client ID** and **client secret** (GCP Console > Credentials >
   the web client) into `terraform.tfvars` (or `TF_VAR_*`):
   ```hcl
   google_oauth_client_id     = "1234567890-xxxx.apps.googleusercontent.com"
   google_oauth_client_secret = "GOCSPX-xxxxxxxx"
   ```
3. `terraform apply` — the `google.com` IdP config is created/enabled. Until
   `google_oauth_client_id` is set, the Google IdP resource is skipped
   (`count = 0`) and the rest of the infra still applies.

> The Flutter app's Google sign-in also needs the **iOS OAuth client ID** and
> its reversed-client-ID URL scheme, which come from the app's
> `GoogleService-Info.plist` (regenerate it from the Firebase console after
> enabling Google). That is app-side config, separate from the web client above.

## Apple sign-in (manual finish)

Apple cannot be fully expressed in Terraform. Steps:

1. In the Apple Developer portal create: an **App ID** (`com.olympuslabs.xplore`)
   with Sign in with Apple enabled, a **Services ID**, and a **Key (.p8)** with
   Sign in with Apple. Note the **Team ID** and **Key ID**. Set the Services ID
   return URL to `https://xplore-a7012.firebaseapp.com/__/auth/handler`.
2. Put the values in `terraform.tfvars`:
   ```hcl
   apple_services_id = "com.olympuslabs.xplore.signin"
   apple_team_id     = "XXXXXXXXXX"
   apple_key_id      = "XXXXXXXXXX"
   apple_private_key = "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
   ```
3. `terraform apply` to create the Apple IdP config. Then finish in
   **Firebase Console > Authentication > Sign-in method > Apple** (the Team ID /
   Key ID / private key portions that the Terraform resource cannot set).

Until `apple_services_id` is set, the Apple IdP resource is skipped (count = 0)
and the rest of the infra still applies.

## Trip invite deep links (FEAT-003) — manual Mac/Xcode + hosting follow-up

The in-app invite flow (create link, share, preview, accept/join, member-cap
enforcement, Firestore rules) ships and is exercised headlessly. What is **not**
wired here — because it needs a Mac/Xcode + a hosted domain and cannot be tested
in the Linux/CI environment — is the OS-level **universal link** delivery. Until
the steps below are done, shared links are valid strings but tapping one will
not open the app.

> **Domain decided:** `xplore.olympuslabs.ai` (subdomain of the owned
> `olympuslabs.ai`). `InviteLink.base` in
> `lib/features/trip/services/invite_link.dart` is already set to
> `https://xplore.olympuslabs.ai/join`, and the iOS Associated Domains
> entitlement (`applinks:xplore.olympuslabs.ai`) is in
> `ios/Runner/Runner.entitlements`. Deployable hosting artifacts are staged in
> `infra/hosting/`. Production enablement (the steps below) is intentionally
> deferred until launch + >100 users — tracked in **GitHub #99**.

### 1. Apple App Site Association (AASA) file — hosting
Serve `infra/hosting/apple-app-site-association` at
**`https://xplore.olympuslabs.ai/.well-known/apple-app-site-association`**
(`application/json`, **no** `.json` extension, HTTPS, no redirects):

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["NY5PB8UM8W.com.olympuslabs.xplore"],
        "components": [{ "/": "/join*", "comment": "Trip invite links" }]
      }
    ]
  }
}
```

`NY5PB8UM8W` is the Apple Developer Team ID (same one used for Sign in with Apple
above); the bundle id is `com.olympuslabs.xplore`. Since `olympuslabs.ai` is on
Cloudflare and nothing else lives on the subdomain yet, the simplest host is the
staged **Cloudflare Worker** (`infra/hosting/aasa-worker.js`):

```bash
cd infra/hosting && npx wrangler deploy aasa-worker.js --name xplore-aasa
```

Then add a **proxied** `xplore` DNS record (e.g. `AAAA` → `100::`, orange cloud
ON) and bind the Worker to the route `xplore.olympuslabs.ai/*`. (If a web app
later lives on this subdomain, drop the Worker and ship the AASA inside the web
build's `web/.well-known/` instead.)

### 2. Associated Domains entitlement — Xcode
Already added to `ios/Runner/Runner.entitlements`:

```text
applinks:xplore.olympuslabs.ai
```

This still requires the **Associated Domains** capability to be enabled on the
`com.olympuslabs.xplore` App ID in the Apple Developer portal. (Repeat the
entitlement on the macOS target if macOS universal links are wanted.)

### 3. App-side delivery
`app_links` is already wired (`DeepLinkService` + `DeepLinkHandler` in
`lib/features/trip/`); no extra Flutter code is needed. The handler parses
`*/join?trip=...&token=...`, waits for auth if needed, then pushes the join
screen.

### 4. Verify (requires a real device or simulator)
- `xcrun simctl openurl booted "https://xplore.olympuslabs.ai/join?trip=<id>&token=<tok>"`
  (or tap a link in Notes/Messages on a device) should foreground the app on
  the join-confirmation screen.
- Apple's CDN caches the AASA; use a fresh install / `swcutil` to debug.

### Security follow-up (tracked, not blocking the cut line)
The join write is gated by the `validTripJoin` Firestore rule (self-add only +
member cap). Invite **revocation/expiry** is validated client-side against the
readable invite doc, and the random 20-char trip id + token act as the
capability. A hardened version (server-side token verification, e.g. a Cloud
Function or a rule that cross-checks the invite doc) is a future enhancement.

## State & secrets

- Local state (`infra/terraform.tfstate`) is git-ignored.
- `terraform.tfvars` (with Apple secrets) is git-ignored. Use `TF_VAR_*` env
  vars in CI.
- `.terraform.lock.hcl` is committed.
- To migrate to a remote GCS backend later, see the commented block in
  `backend.tf`.

## Remaining limitations

- RTDB rules applied via REST (`null_resource`), not a native resource.
- Apple provider requires the manual console finish above.
