output "database_url" {
  description = "Realtime Database URL."
  value       = google_firebase_database_instance.default.database_url
}
