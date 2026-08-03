locals {
  # Always update the gcs_version when updating this file
  gcs_version = "1.8"
}

# Enable the Google Cloud Storage API
resource "google_project_service" "storage_api" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  service = "storage.googleapis.com"

  # Ensures the API stays enabled if the resource is removed from Terraform
  disable_on_destroy = false
}

resource "google_project_service" "storagetransfer" {
  project = var.project_id
  service = "storagetransfer.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "pubsub" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  service = "pubsub.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "cloudasset" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  service = "cloudasset.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service_identity" "cloudasset" {
  provider = google-beta
  count    = var.is_gcs_enabled ? 1 : 0
  project  = var.project_id
  service  = "cloudasset.googleapis.com"

  depends_on = [google_project_service.cloudasset]
}

data "google_storage_transfer_project_service_account" "storagetransfer" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id

  depends_on = [google_project_service.storagetransfer]
}

resource "google_project_iam_member" "storagetransfer_service_agent_pubsub_editor" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/pubsub.editor"
  member  = data.google_storage_transfer_project_service_account.storagetransfer[0].member

  depends_on = [
    data.google_storage_transfer_project_service_account.storagetransfer,
  ]
}

data "google_storage_project_service_account" "gcs" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id

  depends_on = [google_project_service.storage_api]
}

resource "google_project_iam_member" "storage_service_agent_pubsub_publisher" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = data.google_storage_project_service_account.gcs[0].member

  depends_on = [
    google_project_service.pubsub,
  ]
}

resource "google_project_iam_member" "cloudasset_service_agent_pubsub_publisher" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = google_project_service_identity.cloudasset[0].member

  depends_on = [
    google_project_service.pubsub,
    google_project_service_identity.cloudasset,
  ]
}

# Enable Storage Insights so Clumio can configure GCS inventory reports.
resource "google_project_service" "storageinsights" {
  project = var.project_id
  service = "storageinsights.googleapis.com"

  disable_on_destroy = false
}

# Grant the Storage Insights service agent project-level insightsCollectorService so it can read
# source buckets when generating inventory reports.
resource "google_project_service_identity" "storageinsights" {
  provider = google-beta
  count    = var.is_gcs_enabled ? 1 : 0
  project  = var.project_id
  service  = "storageinsights.googleapis.com"

  depends_on = [google_project_service.storageinsights]
}

resource "google_project_iam_member" "insights_collector" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/storage.insightsCollectorService"
  member  = google_project_service_identity.storageinsights[0].member
}

resource "google_project_service" "monitoring_api" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

resource "google_storage_bucket" "clumio_inventory_bridge" {
  for_each = local.regions_to_create_clumio_inventory_bridge_bucket

  project                  = var.project_id
  name                     = "clumio-inventory-bridge-${each.key}-${local.clumio_inventory_bridge_token_hash}"
  location                 = each.key
  storage_class            = "STANDARD"
  public_access_prevention = "enforced"
  labels                   = var.gcs_inventory_bridge_bucket_labels

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }

  depends_on = [google_project_service.storage_api]
}

resource "google_project_iam_custom_role" "clumio_gcs_inventory_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSInvPermission_${local.sanitized_clumio_token}"
  title       = "ClumioGCSInventoryPermissions"
  description = "Allow read only access to list and inspect GCS buckets for Clumio inventory"
  permissions = [
    "storage.buckets.list",
    "storage.buckets.get",
    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.list",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_inventory_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_inventory_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

resource "google_project_iam_custom_role" "clumio_gcs_backup_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSBackupPermissions_${local.sanitized_clumio_token}"
  title       = "ClumioGCSBackupPermissions"
  description = "Allows read only access to GCS objects and manage bucket configuration for Clumio backup"
  permissions = [
    # Read source objects and bucket metadata for backup.
    "storage.objects.list",
    "storage.objects.get",
    "storage.buckets.list",
    "storage.buckets.get",

    # Configure buckets for inventory bridging and continuous backup notifications.
    "storage.buckets.create",
    "storage.buckets.update",
    "storage.buckets.getObjectInsights",

    # Manage the Storage Transfer Service inventory replication job.
    "storagetransfer.jobs.create",
    "storagetransfer.jobs.list",
    "storagetransfer.jobs.update",
    "storagetransfer.jobs.get",
    "storagetransfer.projects.getServiceAccount",

    # Manage Storage Insights inventory report configuration.
    "storageinsights.reportConfigs.get",
    "storageinsights.reportConfigs.list",
    "storageinsights.reportConfigs.create",
    "storageinsights.reportConfigs.delete",

    # Read bucket size metrics from Cloud Monitoring.
    "monitoring.timeSeries.list",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_backup_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_backup_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

# Read and set IAM policy on the Clumio inventory-bridge bucket only (condition-scoped below), so the
# service account can grant the Storage Transfer and Storage Insights agents access to it.
resource "google_project_iam_custom_role" "clumio_gcs_bucket_iam_policy_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSBucketIamPolicy_${local.sanitized_clumio_token}"
  title       = "ClumioGCSBucketIamPolicyPermissions"
  description = "Allow Clumio to read and set bucket IAM policy on the Clumio inventory-bridge bucket only"
  permissions = [
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_bucket_iam_policy_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_bucket_iam_policy_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"

  condition {
    title       = "clumio_inventory_bridge_buckets_only"
    description = "Restrict bucket IAM policy management to Clumio-created and customer-provided inventory-bridge buckets"
    expression  = "resource.type == \"storage.googleapis.com/Bucket\" && (${local.inventory_bridge_bucket_iam_resource_expression})"
  }
}

resource "google_project_iam_custom_role" "clumio_gcs_restore_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSRestorePermissions_${local.sanitized_clumio_token}"
  title       = "ClumioGCSRestorePermissions"
  description = "Allow write access to GCS objects for Clumio restore"
  permissions = [
    # Write and overwrite objects in the restore target bucket.
    "storage.objects.create",
    "storage.objects.delete",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_restore_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_restore_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

resource "google_project_iam_custom_role" "clumio_delta_topic_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "DeltaTopicPermission_${local.sanitized_clumio_token}"
  title       = "ClumioDeltaTopicPermissions"
  description = "Allow exact customer delta topic IAM management for Clumio delta ingestion"
  permissions = [
    "pubsub.topics.get",
    "pubsub.topics.getIamPolicy",
    "pubsub.topics.setIamPolicy",
  ]
  stage = "GA"
}

resource "google_pubsub_topic_iam_member" "clumio_delta_topic_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.customer_delta[0].name
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_delta_topic_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

resource "google_project_iam_custom_role" "clumio_delta_federated_sa_policy_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "DeltaFedSAPolicy_${local.sanitized_clumio_token}"
  title       = "ClumioDeltaFederatedSAPolicyPermissions"
  description = "Allow exact IAM policy management on the customer service account used for Clumio delta ingestion"
  permissions = [
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
  ]
  stage = "GA"
}

resource "google_service_account_iam_member" "clumio_delta_federated_sa_policy_permission_iam_binding" {
  count              = var.is_gcs_enabled ? 1 : 0
  service_account_id = local.service_account_details.name
  role               = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_delta_federated_sa_policy_permission[0].role_id}"
  member             = "serviceAccount:${local.service_account_details.email}"
}
