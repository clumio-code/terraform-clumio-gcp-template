// Verifies that a valid project id is passed
data "google_project" "current" {
  project_id = var.project_id
}

# 1) Create the Clumio connection object for this GCP project
resource "clumio_gcp_connection" "this" {
  project_id      = data.google_project.current.project_id
  description     = var.description
  regions         = var.regions
  deployment_type = var.deployment_type
}
# 2) Install GCP resources required by Clumio in your project
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source = "../../"

  clumio_token              = clumio_gcp_connection.this.token
  project_id                = data.google_project.current.project_id
  clumio_control_plane_id   = clumio_gcp_connection.this.clumio_control_plane_id
  clumio_control_plane_role = clumio_gcp_connection.this.clumio_control_plane_role
  is_gcs_enabled            = var.is_gcs_enabled
}
