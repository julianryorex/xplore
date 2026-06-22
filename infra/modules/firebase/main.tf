# Firebase enablement on the existing project. Imported, never created/destroyed.
# Import: terraform import module.firebase.google_firebase_project.default projects/xplore-a7012
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

# The Apple app registered in Phase 0 (com.olympuslabs.xplore), serving iOS + macOS.
# Import: terraform import module.firebase.google_firebase_apple_app.apple <apple_app_id>
resource "google_firebase_apple_app" "apple" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Xplore (Apple)"
  bundle_id    = var.apple_bundle_id

  depends_on = [google_firebase_project.default]
}
