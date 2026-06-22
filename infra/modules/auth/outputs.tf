output "apple_configured" {
  description = "True if the Apple sign-in provider was configured via Terraform."
  value       = local.apple_enabled
}
