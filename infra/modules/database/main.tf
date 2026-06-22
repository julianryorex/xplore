# Default Realtime Database instance already exists; import it.
# Import: terraform import module.database.google_firebase_database_instance.default <project_id>/<region>/<instance>
# e.g. terraform import module.database.google_firebase_database_instance.default xplore-a7012/us-central1/xplore-a7012-default-rtdb
resource "google_firebase_database_instance" "default" {
  provider    = google-beta
  project     = var.project_id
  region      = var.region
  instance_id = var.rtdb_instance
  type        = "DEFAULT_DATABASE"

  lifecycle {
    # Region/type are fixed on the existing instance; avoid accidental recreation.
    ignore_changes = [region, type]
  }
}

# RTDB security rules have no native Terraform resource. Apply them via the REST
# endpoint using a short-lived OAuth token from the user's gcloud login.
# Re-runs whenever the rules file content changes.
resource "null_resource" "rtdb_rules" {
  triggers = {
    rules_sha = filesha256(var.rules_file)
    instance  = var.rtdb_instance
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      TOKEN="$(gcloud auth print-access-token)"
      curl -fsS -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @${var.rules_file} \
        "https://${var.rtdb_instance}.firebaseio.com/.settings/rules.json"
      echo "RTDB rules applied to ${var.rtdb_instance}"
    EOT
  }

  depends_on = [google_firebase_database_instance.default]
}
