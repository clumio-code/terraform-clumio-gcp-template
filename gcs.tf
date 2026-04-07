locals {
  # Always update the gcs_version when updating this file
  gcs_version = "1.0"
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

# Enable Storage Insights so Clumio can configure GCS inventory reports.
resource "google_project_service" "storageinsights" {
  project = var.project_id
  service = "storageinsights.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "monitoring_api" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
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
  member  = "serviceAccount:${google_service_account.federated_sa.email}"
}

resource "google_project_iam_custom_role" "clumio_gcs_backup_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSBackupPermissions_${local.sanitized_clumio_token}"
  title       = "ClumioGCSBackupPermissions"
  description = "Allows read only access to GCS objects for Clumio backup"
  permissions = [
    "storage.objects.list",
    "storage.objects.get",
    "storage.buckets.list",
    "storage.buckets.get",

    "storage.buckets.create",
    "storage.buckets.getObjectInsights",
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",

    "storagetransfer.jobs.create",
    "storagetransfer.jobs.list",
    "storagetransfer.jobs.get",
    "storagetransfer.jobs.update",
    "storagetransfer.projects.getServiceAccount",

    "storageinsights.reportConfigs.get",
    "storageinsights.reportConfigs.list",
    "storageinsights.reportConfigs.create",
    "storageinsights.reportConfigs.update",
    "storageinsights.reportConfigs.delete",

    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.list",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_backup_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_backup_permission[0].role_id}"
  member  = "serviceAccount:${google_service_account.federated_sa.email}"
}

resource "google_project_iam_custom_role" "clumio_gcs_restore_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSRestorePermissions_${local.sanitized_clumio_token}"
  title       = "ClumioGCSRestorePermissions"
  description = "Allow write access to GCS objects for Clumio restore"
  permissions = [
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.update",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_restore_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_restore_permission[0].role_id}"
  member  = "serviceAccount:${google_service_account.federated_sa.email}"
}

resource "google_project_iam_custom_role" "clumio_gcs_cai_feed_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSCAIFeedPermission_${local.sanitized_clumio_token}"
  title       = "ClumioGCSCAIFeedPermissions"
  description = "Allow Cloud Asset Inventory feed management for GCS change ingestion"
  permissions = [
    "cloudasset.feeds.get",
    "cloudasset.feeds.list",
    "cloudasset.feeds.create",
    "cloudasset.feeds.update",
    "cloudasset.feeds.delete",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_cai_feed_permission_iam_binding" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_cai_feed_permission[0].role_id}"
  member  = "serviceAccount:${google_service_account.federated_sa.email}"
}
