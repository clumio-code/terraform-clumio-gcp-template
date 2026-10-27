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

# 2) Install GCP resources required by Clumio in your project, with the Google service agents and
#    their project-level roles owned by your own tooling instead of this module.
#
# With manage_service_agent_bindings = false the module neither materializes the Cloud Asset,
# Storage Insights, Storage Transfer and Cloud Storage service agents (nor Pub/Sub, when the delta
# topic uses CMEK) nor binds their project-level roles. Before you apply, your tooling must have
# created the agents, for example with `gcloud beta services identity create`, and granted
# roles/storagetransfer.serviceAgent to the Storage Transfer agent, roles/pubsub.publisher to the
# Cloud Storage agent and roles/storage.insightsCollectorService to the Storage Insights agent.
#
# The module derives the agent emails from the project number and skips its IAM propagation wait, so
# the agents must already exist and be settled. The grants scoped to resources only the module knows
# (publish on the delta topic, the inventory bridge bucket grants and the CMEK key grants) are still
# applied here.
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

  manage_service_agent_bindings = false
}
