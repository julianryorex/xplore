locals {
  required_apis = [
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "firebase.googleapis.com",
    "identitytoolkit.googleapis.com",
    "firestore.googleapis.com",
    "firebasedatabase.googleapis.com",
    "firebasestorage.googleapis.com",
    "firebaserules.googleapis.com",
    "storage.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  # Keep APIs enabled if we ever `terraform destroy`; never auto-disable.
  disable_on_destroy         = false
  disable_dependent_services = false
}
