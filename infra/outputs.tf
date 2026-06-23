output "project_id" {
  description = "Active Firebase/GCP project."
  value       = var.project_id
}

output "firestore_database" {
  description = "Firestore database name."
  value       = module.firestore.database_name
}

output "rtdb_url" {
  description = "Realtime Database URL."
  value       = module.database.database_url
}

output "storage_bucket" {
  description = "Firebase-linked Cloud Storage bucket."
  value       = module.storage.bucket_name
}

output "apple_auth_configured" {
  description = "Whether the Apple sign-in provider was configured (requires Apple credentials)."
  value       = module.auth.apple_configured
}

output "google_auth_configured" {
  description = "Whether the Google sign-in provider was configured (requires OAuth web client credentials)."
  value       = module.auth.google_configured
}
