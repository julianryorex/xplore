locals {
  # Apple is only wired up once the Services ID is provided. Until then this
  # module just establishes the base Identity Platform config.
  apple_enabled = var.apple_services_id != ""

  # Google sign-in is gated on its OAuth web client credentials being supplied. Enabled
  # ahead of Apple as an interim provider (FEAT-001 §4: Google deferred but the
  # design is provider-agnostic). Terraform owns the IdP config; the underlying
  # OAuth client (id + secret) is created out-of-band in the GCP Credentials
  # console and injected via terraform.tfvars / TF_VAR_*, mirroring Apple's .p8.
  google_enabled                 = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""
  google_credentials_configured  = var.google_oauth_client_id != ""
  google_credentials_have_secret = var.google_oauth_client_secret != ""
}

resource "terraform_data" "validate_google_oauth_credentials" {
  input = local.google_enabled

  lifecycle {
    precondition {
      condition     = local.google_credentials_configured == local.google_credentials_have_secret
      error_message = "google_oauth_client_id and google_oauth_client_secret must be provided together, or both left empty."
    }
  }
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

# Sign in with Google. Gated on the OAuth web client credentials being present.
#
# Terraform cannot mint the OAuth 2.0 web client itself (see the note in
# locals). Create it once in GCP Console > APIs & Services > Credentials (or let
# Firebase auto-create it when Google sign-in is first toggled), then provide
# google_oauth_client_id / google_oauth_client_secret via terraform.tfvars or
# TF_VAR_*. The client_secret is sensitive and must never be committed.
resource "google_identity_platform_default_supported_idp_config" "google" {
  count = local.google_enabled ? 1 : 0

  provider      = google-beta
  project       = var.project_id
  idp_id        = "google.com"
  client_id     = var.google_oauth_client_id
  client_secret = var.google_oauth_client_secret
  enabled       = true

  depends_on = [google_identity_platform_config.default]
}
