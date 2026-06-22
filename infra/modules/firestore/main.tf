# The default database already exists in this project and is imported.
# xplore-a7012 currently uses Firestore in Datastore mode:
#   location_id = "nam5"
#   type        = "DATASTORE_MODE"
#
# Do not change location_id or type casually; either change forces replacement
# of the default database.
resource "google_firestore_database" "default" {
  provider    = google-beta
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = var.firestore_type

  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "ABANDON"

  lifecycle {
    prevent_destroy = true
  }
}

# Named Firestore Native database used by the Flutter app. The existing default
# database is Datastore mode, which cannot be used by Firebase mobile/web SDKs.
resource "google_firestore_database" "app" {
  provider    = google-beta
  project     = var.project_id
  name        = var.app_database_id
  location_id = var.app_location
  type        = "FIRESTORE_NATIVE"

  delete_protection_state = "DELETE_PROTECTION_ENABLED"
  deletion_policy         = "DELETE"
}

# Firestore security rules from rules/firestore.rules, released to the named
# app database. For non-default databases the release name is cloud.firestore/<database-id>.
resource "google_firebaserules_ruleset" "firestore" {
  provider = google-beta
  project  = var.project_id

  source {
    files {
      name    = "firestore.rules"
      content = file(var.rules_file)
    }
  }

  depends_on = [google_firestore_database.app]
}

resource "google_firebaserules_release" "firestore" {
  provider     = google-beta
  project      = var.project_id
  name         = "cloud.firestore/${google_firestore_database.app.name}"
  ruleset_name = google_firebaserules_ruleset.firestore.name

  lifecycle {
    replace_triggered_by = [google_firebaserules_ruleset.firestore]
  }
}
