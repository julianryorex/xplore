terraform {
  # Local state for now. State files are git-ignored (see root .gitignore).
  backend "local" {
    path = "terraform.tfstate"
  }

  # To migrate to a remote GCS backend later, create a bucket (e.g.
  # gs://xplore-a7012-tfstate) and replace the block above with:
  #
  # backend "gcs" {
  #   bucket = "xplore-a7012-tfstate"
  #   prefix = "firebase-infra"
  # }
  #
  # then run: terraform init -migrate-state
}
