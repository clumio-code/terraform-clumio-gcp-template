provider "google" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
}

provider "google-beta" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
}

data "google_project" "current" {
  project_id = var.project_id
}

#  Get the service account details if SA is provided by customer
data "google_service_account" "customer_provided_sa" {
  count      = local.create_service_account ? 0 : 1
  account_id = var.customer_service_account_email
}

locals {
  sanitized_clumio_token = replace(var.clumio_token, "-", "")
  # Always update the config_version when updating this file
  config_version = "2.2"
  # The template will create a SA if customer has not provided one
  create_service_account = length(var.customer_service_account_email) == 0
  # Points to customer provided SA if provided, else points to the SA created by this template
  service_account_details = local.create_service_account ? google_service_account.clumio_created_sa[0] : data.google_service_account.customer_provided_sa[0]
  regions_by_name = {
    for r in var.region_configuration : r.region => r
  }
  regions_to_create_clumio_inventory_bridge_bucket = {
    for region, cfg in local.regions_by_name : region => cfg
    if var.is_gcs_enabled && cfg.create_clumio_inventory_bridge_bucket
  }
}

resource "google_service_account" "clumio_created_sa" {
  count        = local.create_service_account ? 1 : 0
  account_id   = "clumio-protect-sa-${substr(local.sanitized_clumio_token, 0, 12)}"
  display_name = "Service account in customer's account that will be impersonated by Clumio"
}

resource "google_service_account_iam_member" "clumio_sa_user" {
  # Allow the Clumio service account to impersonate customer service account.
  service_account_id = local.service_account_details.name
  role               = "roles/iam.serviceAccountUser"
  # Customer side SA only allow's Clumio's SA to impersonate it
  member = "serviceAccount:${var.clumio_service_account_email}"
}

resource "google_service_account_iam_member" "allow_token_creator" {
  # Grant ability to mint access tokens once impersonation is established.
  service_account_id = local.service_account_details.name
  role               = "roles/iam.serviceAccountTokenCreator"

  member = "serviceAccount:${var.clumio_service_account_email}"
}


resource "clumio_post_process_gcp_connection" "post_process" {
  depends_on = [
    google_service_account.clumio_created_sa,
    google_service_account_iam_member.clumio_sa_user,
    google_project_service.monitoring_api,
    google_project_service.storage_api,
    google_project_iam_custom_role.clumio_gcs_backup_permission,
    google_project_iam_custom_role.clumio_gcs_bucket_iam_policy_permission,
    google_project_iam_custom_role.clumio_gcs_delta_topic_permission,
    google_project_iam_custom_role.clumio_gcs_inventory_permission,
    google_project_iam_custom_role.clumio_gcs_restore_permission,
    google_project_iam_member.clumio_gcs_backup_permission_iam_binding,
    google_project_iam_member.clumio_gcs_bucket_iam_policy_permission_iam_binding,
    google_pubsub_topic_iam_member.clumio_gcs_delta_topic_permission_iam_binding,
    google_project_iam_member.clumio_gcs_inventory_permission_iam_binding,
    google_project_iam_member.clumio_gcs_restore_permission_iam_binding,
    google_project_iam_member.cloudasset_service_agent_pubsub_publisher,
    google_project_iam_member.storage_service_agent_pubsub_publisher,
    google_project_iam_member.storagetransfer_service_agent_pubsub_editor,
    google_project_service_identity.storageinsights,
    google_project_iam_member.insights_collector,
    google_project_service.cloudasset,
    google_storage_bucket.clumio_inventory_bridge,
    google_pubsub_topic.customer_delta,
    google_cloud_asset_project_feed.customer_delta,
    # When adding or removing resources update this list
    # This ensures that the post process call back is made after everything else is provisioned
  ]

  project_id            = var.project_id
  project_name          = data.google_project.current.name
  project_number        = data.google_project.current.number
  token                 = var.clumio_token
  service_account_email = local.service_account_details.email
  config_version        = local.config_version
  protect_gcs_version   = local.gcs_version
  regions               = [for r in var.region_configuration : r.region]
  region_configuration = [for r in var.region_configuration : {
    region = r.region
    inventory_bridge_bucket_name = (
      var.is_gcs_enabled && r.create_clumio_inventory_bridge_bucket
      ? google_storage_bucket.clumio_inventory_bridge[r.region].name
      : "clumio-inventory-bridge-${r.region}-${var.project_id}"
    )
  }]
  properties = var.is_gcs_enabled ? {
    customer_delta_topic_id = google_pubsub_topic.customer_delta[0].id,
  } : {}
}
