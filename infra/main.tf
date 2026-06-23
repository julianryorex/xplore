module "firebase" {
  source = "./modules/firebase"

  project_id      = var.project_id
  apple_app_id    = var.apple_app_id
  apple_bundle_id = var.apple_bundle_id

  depends_on = [google_project_service.required]
}

module "auth" {
  source = "./modules/auth"

  project_id        = var.project_id
  apple_services_id = var.apple_services_id
  apple_team_id     = var.apple_team_id
  apple_key_id      = var.apple_key_id
  apple_private_key = var.apple_private_key

  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret

  depends_on = [google_project_service.required, module.firebase]
}

module "firestore" {
  source = "./modules/firestore"

  project_id         = var.project_id
  firestore_location = var.firestore_location
  firestore_type     = var.firestore_type
  app_database_id    = var.app_firestore_database_id
  app_location       = var.app_firestore_location
  rules_file         = "${path.module}/rules/firestore.rules"

  depends_on = [google_project_service.required, module.firebase]
}

module "database" {
  source = "./modules/database"

  project_id    = var.project_id
  region        = var.region
  rtdb_instance = var.rtdb_instance
  rules_file    = "${path.module}/rules/database.rules.json"

  depends_on = [google_project_service.required, module.firebase]
}

module "storage" {
  source = "./modules/storage"

  project_id     = var.project_id
  storage_bucket = var.storage_bucket
  rules_file     = "${path.module}/rules/storage.rules"

  depends_on = [google_project_service.required, module.firebase]
}
