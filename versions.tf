terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    clumio = {
      source = "clumio-code/clumio"
    }
  }
}
