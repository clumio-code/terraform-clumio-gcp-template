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
  # Short, collision-resistant token hash used to isolate the inventory-bridge
  # bucket per onboarding (same project can onboard to multiple orgs/NS).
  # sha256 spreads entropy so the truncated prefix stays unique; 12 hex chars
  # keeps the bucket name within GCS's 63-char limit across all regions.
  clumio_inventory_bridge_token_hash = substr(sha256(local.sanitized_clumio_token), 0, 12)
  # Always update the config_version when updating this file
  config_version = "2.2"
  # The template will create a SA if customer has not provided one
  create_service_account = length(var.customer_service_account_email) == 0
  # Points to customer provided SA if provided, else points to the SA created by this template
  service_account_details = local.create_service_account ? google_service_account.clumio_created_sa[0] : data.google_service_account.customer_provided_sa[0]
  regions_by_name = {
    for r in var.region_configuration : r.region => r
  }
  # Create a bucket only when the customer did not provide an existing one for the region.
  regions_to_create_clumio_inventory_bridge_bucket = {
    for region, cfg in local.regions_by_name : region => cfg
    if var.is_gcs_enabled && trimspace(cfg.using_custom_inventory_bridge_bucket) == ""
  }

  # Customer-provided inventory bridge bucket names (used to scope IAM policy management in gcs.tf).
  custom_inventory_bridge_bucket_names = [
    for r in var.region_configuration : r.using_custom_inventory_bridge_bucket
    if trimspace(r.using_custom_inventory_bridge_bucket) != ""
  ]

  # CEL resource matcher for the bucket IAM policy permission: allow Clumio-created buckets
  # (matched by name prefix) plus any customer-provided buckets (matched by exact name).
  inventory_bridge_bucket_iam_resource_expression = join(" || ", concat(
    ["resource.name.startsWith(\"projects/_/buckets/clumio-inventory-bridge-\")"],
    [for name in local.custom_inventory_bridge_bucket_names : "resource.name == \"projects/_/buckets/${name}\""],
  ))

  # Whether the module manages the GCS custom roles and their bindings. Both are gated on GCS being
  # enabled; when manage_gcs_iam is false they are provisioned outside this module.
  manage_gcs_iam = var.is_gcs_enabled && var.manage_gcs_iam

  # Stable custom-role IDs for the GCS roles. Defined as locals (rather than only on the role
  # resources) so that the role definition and its IAM binding share a single source of truth for the
  # id, instead of the binding reading it back off the (now optional) role resource via [0].role_id.
  gcs_custom_role_ids = {
    inventory        = "GCSInvPermission_${local.sanitized_clumio_token}"
    backup           = "GCSBackupPermissions_${local.sanitized_clumio_token}"
    bucket_iam       = "GCSBucketIamPolicy_${local.sanitized_clumio_token}"
    restore          = "GCSRestorePermissions_${local.sanitized_clumio_token}"
    delta_topic      = "DeltaTopicPermission_${local.sanitized_clumio_token}"
    delta_federation = "DeltaFedSAPolicy_${local.sanitized_clumio_token}"
  }
  gcs_custom_role_names = {
    for key, role_id in local.gcs_custom_role_ids : key => "projects/${var.project_id}/roles/${role_id}"
  }
}

resource "google_service_account" "clumio_created_sa" {
  count        = local.create_service_account ? 1 : 0
  account_id   = "clumio-protect-sa-${substr(local.sanitized_clumio_token, 0, 12)}"
  display_name = "Service account in customer's account that will be impersonated by Clumio"
}

resource "google_service_account_iam_member" "clumio_sa_user" {
  # Allow the Clumio service account to impersonate customer service account.
  count              = var.manage_service_account_impersonation ? 1 : 0
  service_account_id = local.service_account_details.name
  role               = "roles/iam.serviceAccountUser"
  # Customer side SA only allow's Clumio's SA to impersonate it
  member = "serviceAccount:${var.clumio_service_account_email}"
}

resource "google_service_account_iam_member" "allow_token_creator" {
  # Grant ability to mint access tokens once impersonation is established.
  count              = var.manage_service_account_impersonation ? 1 : 0
  service_account_id = local.service_account_details.name
  role               = "roles/iam.serviceAccountTokenCreator"

  member = "serviceAccount:${var.clumio_service_account_email}"
}


resource "clumio_post_process_gcp_connection" "post_process" {
  # depends_on requires static resource references. Referencing a resource that is gated by count is
  # valid even when its count is 0 (it simply contributes no instances to the dependency graph), so
  # the optional roles, bindings and impersonation grants can stay listed here regardless of whether
  # this module manages them.
  depends_on = [
    google_service_account.clumio_created_sa,
    google_service_account_iam_member.clumio_sa_user,
    google_project_service.monitoring_api,
    google_project_service.storage_api,
    google_project_iam_custom_role.clumio_gcs_backup_permission,
    google_project_iam_custom_role.clumio_gcs_bucket_iam_policy_permission,
    google_project_iam_custom_role.clumio_delta_federated_sa_policy_permission,
    google_project_iam_custom_role.clumio_delta_topic_permission,
    google_project_iam_custom_role.clumio_gcs_inventory_permission,
    google_project_iam_custom_role.clumio_gcs_restore_permission,
    google_project_iam_member.clumio_gcs_backup_permission_iam_binding,
    google_project_iam_member.clumio_gcs_bucket_iam_policy_permission_iam_binding,
    google_pubsub_topic_iam_member.clumio_delta_topic_permission_iam_binding,
    google_service_account_iam_member.clumio_delta_federated_sa_policy_permission_iam_binding,
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
  # When GCS is disabled there are no inventory bridge buckets, so emit no region
  # configuration at all. When enabled, use the Clumio-created bucket where no custom
  # bucket was provided, else pass through the customer-provided bucket name. Gating the
  # whole list on is_gcs_enabled keeps the created-bucket reference in lock-step with
  # regions_to_create_clumio_inventory_bridge_bucket (is_gcs_enabled && custom == ""),
  # so a non-created bucket is never referenced.
  region_configuration = var.is_gcs_enabled ? [for r in var.region_configuration : {
    region = r.region
    inventory_bridge_bucket_name = (
      trimspace(r.using_custom_inventory_bridge_bucket) == ""
      ? google_storage_bucket.clumio_inventory_bridge[r.region].name
      : r.using_custom_inventory_bridge_bucket
    )
  }] : []
  properties = var.is_gcs_enabled ? {
    customer_delta_topic_id = google_pubsub_topic.customer_delta[0].id,
  } : {}
}
