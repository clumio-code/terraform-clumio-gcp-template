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

# 2) Install GCP resources required by Clumio in your project, with the impersonation grants owned
#    by your own tooling instead of this module.
#
# With manage_service_account_impersonation = false the module does not grant the Clumio service
# account roles/iam.serviceAccountTokenCreator and roles/iam.serviceAccountUser on the customer
# service account. Your tooling must grant both, to the member
# serviceAccount:<clumio_gcp_connection.this.clumio_service_account>, or Clumio cannot act in the
# project at all.
#
# This example therefore requires an existing customer service account. A module-created one would
# only exist after the first apply, and the Clumio post-process handshake at the end of that apply
# already needs the impersonation to work, so the grants cannot be added afterwards without a
# failed first apply.
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

  manage_service_account_impersonation = false
}
