output "apple_configured" {
  description = "True if the Apple sign-in provider was configured via Terraform."
  value       = local.apple_enabled
}

output "google_configured" {
  description = "True if the Google sign-in provider was configured via Terraform."
  value       = local.google_enabled
}
