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
| Auth | `google_identity_platform_config` (base) + Apple IdP (gated) | create/scaffold |
| Firestore / Datastore | existing `(default)` database (`nam5`, `DATASTORE_MODE`) | import / protect |
| Firestore app DB | named `xplore-app` database (`us-east1`, `FIRESTORE_NATIVE`) + rules | create |
| Realtime DB | `google_firebase_database_instance` + RTDB rules (REST) | import + apply |
| Storage | `google_firebase_storage_bucket` + rules | import |
| APIs | `google_project_service` (firebase, identitytoolkit, firestore, ...) | enable |

Auth providers: **Apple only** (Anonymous + Google deferred per FEAT-001).

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
