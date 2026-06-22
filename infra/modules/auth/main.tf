locals {
  # Apple is only wired up once the Services ID is provided. Until then this
  # module just establishes the base Identity Platform config (no providers
  # enabled — Anonymous/Google are deferred per FEAT-001).
  apple_enabled = var.apple_services_id != ""
}

# Base Identity Platform configuration for the project.
# Import (if it already exists): terraform import module.auth.google_identity_platform_config.default <project_id>
resource "google_identity_platform_config" "default" {
  provider = google-beta
  project  = var.project_id

  # No anonymous / email / phone sign-in enabled here (Apple-only product).
  multi_tenant {
    allow_tenants = false
  }
}

# Sign in with Apple. Gated on credentials being present.
#
# NOTE: Identity Platform's Apple provider also needs the Apple Team ID, Key ID,
# and .p8 private key, which this resource cannot express directly. After apply,
# finish in Firebase Console > Authentication > Sign-in method > Apple (paste
# Services ID / Team ID / Key ID / private key). The var.apple_team_id /
# apple_key_id / apple_private_key inputs are kept for that documented manual
# step and future provider support.
resource "google_identity_platform_default_supported_idp_config" "apple" {
  count = local.apple_enabled ? 1 : 0

  provider      = google-beta
  project       = var.project_id
  idp_id        = "apple.com"
  client_id     = var.apple_services_id
  client_secret = var.apple_private_key
  enabled       = true

  depends_on = [google_identity_platform_config.default]
}
