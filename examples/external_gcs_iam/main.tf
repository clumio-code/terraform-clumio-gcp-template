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

# 2) Install GCP resources required by Clumio in your project, with the GCS custom roles and their
#    bindings owned by your own tooling instead of this module.
#
# With manage_gcs_iam = false the module creates neither the ClumioGCSInventoryPermissions,
# ClumioGCSBackupPermissions and ClumioGCSRestorePermissions custom roles nor their project-level
# bindings to the customer service account. Before Clumio can inventory, back up or restore, your
# tooling must bind the customer service account to roles carrying the same permissions (listed in
# gcs.tf of the module). Those bindings may be scoped more narrowly than the project, for example
# per bucket; Clumio then protects only the buckets they cover.
#
# Everything else, including the customer service account and its impersonation grants, the API
# enablement, the service agents and the inventory bridge resources, is still managed here.
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

  manage_gcs_iam = false
}
