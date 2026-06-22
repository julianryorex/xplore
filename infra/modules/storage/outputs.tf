output "bucket_name" {
  description = "Firebase-linked Cloud Storage bucket name."
  value       = google_firebase_storage_bucket.default.bucket_id
}
