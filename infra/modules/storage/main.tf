# Link the existing default Cloud Storage bucket to Firebase. Import if present.
# Import: terraform import module.storage.google_firebase_storage_bucket.default <project_id>/<bucket>
resource "google_firebase_storage_bucket" "default" {
  provider  = google-beta
  project   = var.project_id
  bucket_id = var.storage_bucket
}

# Storage security rules from rules/storage.rules.
resource "google_firebaserules_ruleset" "storage" {
  provider = google-beta
  project  = var.project_id

  source {
    files {
      name    = "storage.rules"
      content = file(var.rules_file)
    }
  }

  depends_on = [google_firebase_storage_bucket.default]
}

resource "google_firebaserules_release" "storage" {
  provider     = google-beta
  project      = var.project_id
  name         = "firebase.storage/${var.storage_bucket}"
  ruleset_name = google_firebaserules_ruleset.storage.name

  lifecycle {
    replace_triggered_by = [google_firebaserules_ruleset.storage]
  }
}
