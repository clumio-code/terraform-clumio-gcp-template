locals {
  # Always update the gcs_version when changing this file's resources; comment-only edits do
  # not bump it.
  gcs_version = "1.15"
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
  count   = var.is_gcs_enabled ? 1 : 0
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

# STS needs this to create the topic and subscription behind the inventory replication job.
resource "google_project_iam_member" "storagetransfer_service_agent" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/storagetransfer.serviceAgent"
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

# Storage Transfer creates its own topic at job-creation time, so there is no topic to scope to at
# apply time; the GCS service agent needs project-wide publish for cross-bucket replication.
# Reference: https://docs.cloud.google.com/storage-transfer/docs/cross-bucket-replication#get-required-roles
resource "google_project_iam_member" "storage_service_agent_pubsub_publisher" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = data.google_storage_project_service_account.gcs[0].member

  depends_on = [
    google_project_service.pubsub,
  ]
}

# The Clumio delta feed publishes only to this topic, so the Cloud Asset agent is granted publish
# on the topic rather than project-wide.
resource "google_pubsub_topic_iam_member" "cloudasset_service_agent_pubsub_publisher" {
  count   = var.is_gcs_enabled ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.customer_delta[0].name
  role    = "roles/pubsub.publisher"
  member  = google_project_service_identity.cloudasset[0].member
}

# Enable Storage Insights so Clumio can configure GCS inventory reports.
resource "google_project_service" "storageinsights" {
  count   = var.is_gcs_enabled ? 1 : 0
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

  project                     = var.project_id
  name                        = "clumio-inventory-bridge-${each.key}-${local.clumio_inventory_bridge_token_hash}"
  location                    = each.key
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  labels                      = var.gcs_inventory_bridge_bucket_labels

  # force_destroy is intentionally left false (the default) to prevent Terraform from
  # deleting a bucket that still holds inventory report objects. The lifecycle_rule below
  # continuously writes objects retained for 30 days, so `terraform destroy` will fail on
  # the non-empty bucket by design. Teardown requires manually emptying the bucket first
  # (e.g. `gcloud storage rm --recursive gs://<bucket>/**`) before destroy will succeed.
  force_destroy = false

  # Recovery posture is pinned intentionally, not left to provider/API defaults:
  #   - Object versioning is omitted: inventory reports are regenerated on every inventory
  #     run, so a deleted/overwritten report is reproduced by the next one. Noncurrent
  #     versions would add storage cost and lifecycle-management overhead with no recovery
  #     benefit for reproducible data.
  #   - No lifecycle { prevent_destroy = true }: the bucket must stay destroyable so
  #     offboarding (terraform destroy) and re-onboarding (a new clumio_token changes the
  #     name and forces replacement) work. Replacing an immutable attribute (e.g. location
  #     or the token-derived name) deletes the bucket and its contents by design.
  #   - Soft delete is pinned off below for the same regenerable-data reason: a retention
  #     window would only add soft-deleted-object storage cost without protecting any
  #     non-reproducible data.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  # Optional customer-managed encryption key (CMEK). No-op when the region's
  # inventory_bridge_kms_key_name is empty, in which case the bucket uses Google-managed
  # encryption. When set, the Cloud Storage service agent must already hold
  # cryptoKeyEncrypterDecrypter on the key (see google_kms_crypto_key_iam_member below and
  # the depends_on) or the create is rejected.
  dynamic "encryption" {
    # trimspace here matches the normalization used to build local.inventory_bridge_kms_keys, so the
    # bucket's default key and the service-agent grants always reference the identical key string.
    for_each = trimspace(each.value.inventory_bridge_kms_key_name) != "" ? [trimspace(each.value.inventory_bridge_kms_key_name)] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }

  depends_on = [
    google_project_service.storage_api,
    google_kms_crypto_key_iam_member.inventory_bridge_gcs_agent_cmek,
  ]
}

# CMEK key access for the service agents that read/write the inventory-bridge bucket. These are
# created only for keys actually referenced by a region (local.inventory_bridge_kms_keys), so they
# are a no-op when no CMEK is configured. The deploying identity must be able to set IAM policy on
# the customer's key (roles/cloudkms.admin, or any role granting cloudkms.cryptoKeys.setIamPolicy
# on it). A customer who prefers to manage key IAM themselves can pre-grant these roles and remove
# these resources.

# Enable the Cloud KMS API on the client project. With user_project_override + billing_project =
# project_id, both the setIamPolicy calls below and the CMEK bucket create bill KMS usage to
# project_id, so the API must be enabled there even when the key itself lives in another project.
# Gated on there being at least one CMEK key so non-CMEK deployments don't enable an unused API.
# The delta topic key counts here too: a deployment that encrypts only the topic still needs the API.
resource "google_project_service" "cloudkms" {
  count   = length(local.inventory_bridge_kms_keys) > 0 || local.delta_topic_cmek_enabled ? 1 : 0
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_on_destroy = false
}

# 1) Cloud Storage service agent: performs encrypt/decrypt of objects using the bucket default key.
#    This grant is mandatory - without it a bucket create with default_kms_key_name is rejected.
resource "google_kms_crypto_key_iam_member" "inventory_bridge_gcs_agent_cmek" {
  for_each      = local.inventory_bridge_kms_keys
  crypto_key_id = each.value
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_storage_project_service_account.gcs[0].member

  depends_on = [google_project_service.cloudkms]
}

# 2) Storage Insights service agent: writes inventory report objects into the bucket.
resource "google_kms_crypto_key_iam_member" "inventory_bridge_insights_agent_cmek" {
  for_each      = local.inventory_bridge_kms_keys
  crypto_key_id = each.value
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.storageinsights[0].member

  depends_on = [google_project_service.cloudkms]
}

# 3) Storage Transfer service agent: reads/writes objects during inventory replication.
resource "google_kms_crypto_key_iam_member" "inventory_bridge_transfer_agent_cmek" {
  for_each      = local.inventory_bridge_kms_keys
  crypto_key_id = each.value
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_storage_transfer_project_service_account.storagetransfer[0].member

  depends_on = [google_project_service.cloudkms]
}

# CMEK key access for the delta feed topic. Keyed off local.delta_topic_kms_key rather than the
# per-region bucket keys: the topic is project-global, so it takes a single key of its own.

# The Pub/Sub service agent is not created until the API is first used, so it is materialized
# explicitly before the key grant below can reference it.
resource "google_project_service_identity" "pubsub" {
  provider = google-beta
  count    = local.delta_topic_cmek_enabled ? 1 : 0
  project  = var.project_id
  service  = "pubsub.googleapis.com"

  depends_on = [google_project_service.pubsub]
}

# Pub/Sub service agent: encrypts and decrypts messages published to the delta topic. Without this
# grant the topic create is rejected, and publishes fail with FAILED_PRECONDITION.
resource "google_kms_crypto_key_iam_member" "delta_topic_pubsub_agent_cmek" {
  count         = local.delta_topic_cmek_enabled ? 1 : 0
  crypto_key_id = local.delta_topic_kms_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.pubsub[0].member

  depends_on = [google_project_service.cloudkms]
}

resource "google_project_iam_custom_role" "clumio_gcs_inventory_permission" {
  count       = local.manage_gcs_iam ? 1 : 0
  project     = var.project_id
  role_id     = local.gcs_custom_role_ids.inventory
  title       = "ClumioGCSInventoryPermissions"
  description = "Lists GCS buckets and reads project-wide Cloud Monitoring time series for Clumio inventory"
  permissions = [
    "storage.buckets.list",
    "storage.buckets.get",

    # Cloud Monitoring IAM cannot scope this permission to GCS metrics, so this grants project-wide
    # time-series reads. Inventory queries filter responses to GCS object-count and total-byte metrics.
    "monitoring.timeSeries.list",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_inventory_permission_iam_binding" {
  count   = local.manage_gcs_iam ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_inventory_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

resource "google_project_iam_custom_role" "clumio_gcs_backup_permission" {
  count       = local.manage_gcs_iam ? 1 : 0
  project     = var.project_id
  role_id     = local.gcs_custom_role_ids.backup
  title       = "ClumioGCSBackupPermissions"
  description = "Reads GCS objects and project-wide Cloud Monitoring data and configures buckets for Clumio backup"
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

    # Backup inventory reads GCS object-count metrics to choose its listing strategy. Cloud Monitoring IAM
    # cannot scope this permission to GCS metrics, so the role grants project-wide time-series reads.
    "monitoring.timeSeries.list",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_backup_permission_iam_binding" {
  count   = local.manage_gcs_iam ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_backup_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

# Read and set IAM policy on the Clumio inventory-bridge bucket only (condition-scoped below), so the
# service account can grant the Storage Transfer and Storage Insights agents access to it.
resource "google_project_iam_custom_role" "clumio_gcs_bucket_iam_policy_permission" {
  count       = local.manage_gcs_iam ? 1 : 0
  project     = var.project_id
  role_id     = local.gcs_custom_role_ids.bucket_iam
  title       = "ClumioGCSBucketIamPolicyPermissions"
  description = "Allow Clumio to read and set bucket IAM policy on the Clumio inventory-bridge bucket only"
  permissions = [
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
  ]
  stage = "GA"
}

resource "google_project_iam_member" "clumio_gcs_bucket_iam_policy_permission_iam_binding" {
  count   = local.manage_gcs_iam ? 1 : 0
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
  count       = local.manage_gcs_iam ? 1 : 0
  project     = var.project_id
  role_id     = local.gcs_custom_role_ids.restore
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
  count   = local.manage_gcs_iam ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_gcs_restore_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}

resource "google_project_iam_custom_role" "clumio_delta_topic_permission" {
  count       = local.manage_gcs_iam ? 1 : 0
  project     = var.project_id
  role_id     = local.gcs_custom_role_ids.delta_topic
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
  count   = local.manage_gcs_iam ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.customer_delta[0].name
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.clumio_delta_topic_permission[0].role_id}"
  member  = "serviceAccount:${local.service_account_details.email}"
}
