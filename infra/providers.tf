# Quota/billing project is scoped here via user_project_override + billing_project
# so we never need a global `gcloud auth application-default set-quota-project`.
# ADC user login (`gcloud auth application-default login`) is sufficient.

provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}
