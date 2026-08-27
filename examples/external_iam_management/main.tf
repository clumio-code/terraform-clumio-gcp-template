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

# 2) Install the GCP resources required by Clumio, but delegate all supported prerequisites.
#
# In this example the customer's platform tooling owns:
#   - the customer service account (passed in via customer_service_account_email),
#   - the Clumio custom IAM roles and their bindings (manage_gcs_iam = false),
#   - the service-account impersonation grants (manage_service_account_impersonation = false),
#   - the Google API enablement (manage_api_enablement = false), and
#   - the Google service agents/identities and their bindings, incl. CMEK grants
#     (manage_service_agent_bindings = false).
#
# The module then only creates the inventory-bridge bucket, delta topic and Cloud Asset feed, and
# runs the Clumio post-process handshake.
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

  # Delegate every supported prerequisite to external tooling: skip the custom roles and bindings,
  # the impersonation grants, the API enablement, and the service-agent identities/bindings. Each
  # flag defaults to true (original behavior); set only the ones your platform tooling owns.
  manage_gcs_iam                       = false
  manage_service_account_impersonation = false
  manage_api_enablement                = false
  manage_service_agent_bindings        = false
}
