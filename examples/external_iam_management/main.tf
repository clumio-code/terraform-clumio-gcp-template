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

# 2) Install the GCP resources required by Clumio, but delegate IAM management.
#
# In this example the customer's platform tooling owns:
#   - the customer service account (passed in via customer_service_account_email),
#   - the Clumio custom IAM roles and their bindings (manage_gcs_iam = false), and
#   - the service-account impersonation grants (manage_service_account_impersonation = false).
#
# The module still enables the required Google APIs, materializes service agents, and creates the
# inventory-bridge bucket, delta topic and Cloud Asset feed, then runs the Clumio post-process
# handshake.
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source = "../../"

  clumio_token                 = clumio_gcp_connection.this.token
  project_id                   = data.google_project.current.project_id
  region_configuration         = var.region_configuration
  clumio_service_account_email = clumio_gcp_connection.this.clumio_service_account
  is_gcs_enabled               = var.is_gcs_enabled

  # Use an existing, externally-managed customer service account (required when the roles and
  # impersonation grants are managed outside this module, since the module needs the SA email to
  # wire the Clumio post-process handshake and kept resources).
  customer_service_account_email = var.customer_service_account_email

  # Delegate IAM to external tooling: skip the custom roles, their bindings, and the impersonation
  # grants. The module's default for both flags is true (original behavior).
  manage_gcs_iam                       = false
  manage_service_account_impersonation = false
}
