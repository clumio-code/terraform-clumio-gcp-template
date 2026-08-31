terraform {
  # 1.3 is the floor for the whole module: the moved blocks in common.tf need 1.1, and the
  # two-argument optional() defaults in variables.tf need 1.3.
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8.0"
    }
    google-beta = {
      # 5.39 is the first version exposing the `member` attribute on
      # google_project_service_identity (used in gcs.tf). Earlier 5.x fails
      # `terraform validate` with "Unsupported attribute".
      source  = "hashicorp/google-beta"
      version = ">= 5.39, < 8.0"
    }
    clumio = {
      source  = "clumio-code/clumio"
      version = ">= 0.22.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
