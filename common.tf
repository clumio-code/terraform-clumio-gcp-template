provider "google" {
  project = var.project_id
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  sanitized_clumio_token = replace(var.clumio_token, "-", "")
  # Always update the config_version when updating this file
  config_version = "1.0"
}

resource "google_service_account" "federated_sa" {
  # The service account represents the Clumio control plane within the customer's GCP project.
  account_id   = var.clumio_federated_aws_service_account_id
  display_name = "Service account assumed by Clumio AWS role for GCP access"
}

resource "google_iam_workload_identity_pool" "pool" {
  # Pool groups providers related to Clumio federation to keep isolation from other pools.
  project                   = var.project_id
  workload_identity_pool_id = var.clumio_wif_pool_id
  display_name              = "Clumio AWS Pool"
  description               = "Allows Clumio AWS IAM role to federate into GCP"
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  # Provider trusts the Clumio AWS account and limits assumed roles via attribute_condition.
  # attribute_mapping extracts relevant AWS STS assertion fields for fine‑grained IAM binding.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.clumio_wif_provider_id
  display_name                       = "Clumio AWS Provider"
  description                        = "Maps Clumio AWS role identity to GCP"

  aws {
    # The AWS account id of the Clumio control plane whose role will federate into GCP.
    account_id = var.clumio_control_plane_id
  }

  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.principal"
    "attribute.aws_acct" = "assertion.account"
  }
  # Limit to assumed roles from the specified Clumio IAM role only.
  attribute_condition = "assertion.arn.startsWith('${var.clumio_control_plane_role}')"
}

resource "google_service_account_iam_binding" "allow_wi_user" {
  # Allow the federated principal set to impersonate (workloadIdentityUser) the service account.
  service_account_id = google_service_account.federated_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.pool.workload_identity_pool_id}/attribute.aws_acct/${var.clumio_control_plane_id}"
  ]
}

resource "google_service_account_iam_binding" "allow_token_creator" {
  # Grant ability to mint access tokens once impersonation is established.
  service_account_id = google_service_account.federated_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.pool.workload_identity_pool_id}/attribute.aws_acct/${var.clumio_control_plane_id}"
  ]
}

# Enable the IAM Service Account Credentials API required for WIF impersonation
resource "google_project_service" "iam_credentials_api" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"

  # Ensures the API stays enabled if the resource is removed from Terraform
  disable_on_destroy = false
}

resource "clumio_post_process_gcp_connection" "post_process" {
  depends_on = [
    google_service_account_iam_binding.allow_token_creator,
    google_service_account_iam_binding.allow_wi_user,
    google_project_service.iam_credentials_api,
    google_project_service.monitoring_api,
    google_project_service.storage_api,
    google_project_iam_custom_role.clumio_gcs_backup_permission,
    google_project_iam_custom_role.clumio_gcs_cai_feed_permission,
    google_project_iam_custom_role.clumio_gcs_inventory_permission,
    google_project_iam_custom_role.clumio_gcs_restore_permission,
    google_project_iam_member.clumio_gcs_backup_permission_iam_binding,
    google_project_iam_member.clumio_gcs_cai_feed_permission_iam_binding,
    google_project_iam_member.clumio_gcs_inventory_permission_iam_binding,
    google_project_iam_member.clumio_gcs_restore_permission_iam_binding,
    google_project_iam_member.storage_service_agent_pubsub_publisher,
    google_project_iam_member.storagetransfer_service_agent_pubsub_editor
    # When adding or removing resources update this list
    # This ensures that the post process call back is made after everything else is provisioned
  ]

  project_id            = var.project_id
  project_name          = data.google_project.current.name
  project_number        = data.google_project.current.number
  token                 = var.clumio_token
  service_account_email = google_service_account.federated_sa.email
  wif_pool_id           = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  wif_provider_id       = google_iam_workload_identity_pool_provider.aws.workload_identity_pool_provider_id
  config_version        = local.config_version
  protect_gcs_version   = local.gcs_version
}
