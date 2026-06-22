variable "project_id" {
  description = "Existing Firebase/GCP project ID. We do not create or destroy the project itself."
  type        = string
  default     = "xplore-a7012"
}

variable "project_number" {
  description = "Project number for the existing project (used in some resource IDs)."
  type        = string
  default     = "700905798457"
}

variable "region" {
  description = "Default region for provider operations."
  type        = string
  default     = "us-east1"
}

variable "firestore_location" {
  description = "Existing default Firestore/Datastore database location. PERMANENT once set."
  type        = string
  default     = "nam5"
}

variable "firestore_type" {
  description = "Existing default database mode. xplore-a7012 currently uses DATASTORE_MODE, not FIRESTORE_NATIVE."
  type        = string
  default     = "DATASTORE_MODE"
}

variable "app_firestore_database_id" {
  description = "Named Firestore Native database used by the Flutter/Firebase client app."
  type        = string
  default     = "xplore-app"
}

variable "app_firestore_location" {
  description = "Location for the named Firestore Native app database. PERMANENT once set."
  type        = string
  default     = "us-east1"
}

variable "apple_app_id" {
  description = "Firebase Apple app ID to import (com.olympuslabs.xplore). From lib/firebase_options.dart."
  type        = string
  default     = "1:700905798457:ios:b3762811940cfb83c446e8"
}

variable "apple_bundle_id" {
  description = "Apple bundle identifier for the Firebase Apple app."
  type        = string
  default     = "com.olympuslabs.xplore"
}

variable "storage_bucket" {
  description = "Default Cloud Storage bucket linked to Firebase."
  type        = string
  default     = "xplore-a7012.appspot.com"
}

variable "rtdb_instance" {
  description = "Default Realtime Database instance name (without the .firebaseio.com suffix)."
  type        = string
  default     = "xplore-a7012-default-rtdb"
}

# ---------------------------------------------------------------------------
# Apple Sign-In (deferred manual finish)
# Leave these empty to scaffold without enabling the Apple provider. Fill them
# (via terraform.tfvars or TF_VAR_*) once the Apple Developer credentials exist,
# then re-apply to enable Apple sign-in.
# ---------------------------------------------------------------------------
variable "apple_services_id" {
  description = "Apple Services ID (OAuth client_id) for Sign in with Apple. Empty = Apple provider not configured."
  type        = string
  default     = ""
}

variable "apple_team_id" {
  description = "Apple Developer Team ID."
  type        = string
  default     = ""
}

variable "apple_key_id" {
  description = "Apple Sign in with Apple key ID."
  type        = string
  default     = ""
}

variable "apple_private_key" {
  description = "Contents of the Apple .p8 private key. Sensitive."
  type        = string
  default     = ""
  sensitive   = true
}
