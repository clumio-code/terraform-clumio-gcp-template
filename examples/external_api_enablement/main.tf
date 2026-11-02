// Verifies that a valid project id is passed
data "google_project" "current" {
  project_id = var.project_id
}

# 1) Create the Clumio connection object for this GCP project
resource "clumio_gcp_connection" "this" {
  project_id      = data.google_project.current.project_id
  description     = var.description
  regions         = [for r in var.region_configuration : r.region]
  deployment_type = var.deployment_type
}

# 2) Install GCP resources required by Clumio in your project, with Google API enablement owned by
#    your own tooling instead of this module.
#
# With manage_api_enablement = false the module creates no google_project_service resources. Before
# you apply, your tooling must have enabled storage, storagetransfer, pubsub, cloudasset,
# storageinsights and monitoring (all .googleapis.com) on the project, plus cloudkms when a CMEK key
# is configured for an inventory bridge bucket or the delta topic. A missing API is not visible at
# plan time; the apply fails on the first resource that needs it.
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source = "../../"

  clumio_token                   = clumio_gcp_connection.this.token
  project_id                     = data.google_project.current.project_id
  region_configuration           = var.region_configuration
  clumio_service_account_email   = clumio_gcp_connection.this.clumio_service_account
  is_gcs_enabled                 = var.is_gcs_enabled
  customer_service_account_email = var.customer_service_account_email

  manage_api_enablement = false
}
