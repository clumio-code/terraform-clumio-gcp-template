// Verifies that a valid project id is passed
data "google_project" "current" {
  project_id = var.project_id
}

# 1) Create the Clumio connection object for this AWS account+region
resource "clumio_gcp_connection" "this" {
  project_id  = data.google_project.current.project_id
  description = "Onboarded via Terraform"
}
# 2) Install GCP resources required by Clumio in your project
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source = "../../"

  clumio_token          = clumio_gcp_connection.this.token
  project_id            = data.google_project.current.project_id
  clumio_aws_account_id = clumio_gcp_connection.this.clumio_aws_account_id
  clumio_aws_iam_role   = clumio_gcp_connection.this.clumio_aws_iam_role
  is_gcs_enabled        = true
}
