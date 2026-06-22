output "database_name" {
  description = "Named Firestore Native database used by the Flutter app."
  value       = google_firestore_database.app.name
}

output "default_database_name" {
  description = "Existing imported default Datastore-mode database."
  value       = google_firestore_database.default.name
}
