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

resource "google_project_iam_custom_role" "clumio_gcs_inventory_permission" {
  count       = var.is_gcs_enabled ? 1 : 0
  project     = var.project_id
  role_id     = "GCSInvPermission_${local.sanitized_clumio_token}"
  title       = "ClumioGCSInventoryPermissions"
  description = "Allow read only access to list and inspect GCS buckets for Clumio inventory"
  permissions = [
    # AWS: s3:ListAllMyBuckets
    "storage.buckets.list",
    # AWS: s3:GetBucketLocation, s3:GetEncryptionConfiguration, s3:GetBucketVersioning,
    # AWS: s3:GetBucketTagging, s3:GetReplicationConfiguration, s3:GetLifecycleConfiguration,
    # AWS: s3:GetBucketLogging, s3:GetBucketObjectLockConfiguration, s3:GetMetricsConfiguration
    "storage.buckets.get",
    # AWS: s3:GetBucketPolicy
    "storage.buckets.getIamPolicy",
    # GCP-only: necessary for receiving Storage Insight Inventory, only allowing
    # in-project configuration. Clumio will replicate this created bucket to the dataplane.
    "storage.buckets.create",
    # AWS: cloudwatch:GetMetricStatistics (bucket metrics like object count/size)
    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.list",
    # AWS: s3:GetInventoryConfiguration, s3:PutInventoryConfiguration
    "storageinsights.reportConfigs.get",
    "storageinsights.reportConfigs.list",
    "storageinsights.reportConfigs.create",
    "storageinsights.reportConfigs.update",
    "storageinsights.reportConfigs.delete",
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
    # AWS: s3:GetObject, s3:GetObjectVersion, s3:GetObjectTagging, s3:GetObjectVersionTagging
    "storage.objects.get",
    # AWS: s3:ListBucket, s3:ListBucketVersions, s3:ListBucketMultipartUploads
    "storage.objects.list",
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
    # AWS: s3:PutObject
    "storage.objects.create",
    # AWS: s3:DeleteObject (creates delete markers when bucket versioning is enabled)
    "storage.objects.delete",
    # AWS: s3:PutObjectTagging
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
    # AWS: events:DescribeRule
    "cloudasset.feeds.get",
    # AWS: events:ListTargetsByRule
    "cloudasset.feeds.list",
    # AWS: events:PutRule, events:PutTargets
    "cloudasset.feeds.create",
    # AWS: events:PutRule, events:PutTargets (updates)
    "cloudasset.feeds.update",
    # AWS: events:DeleteRule, events:RemoveTargets
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
