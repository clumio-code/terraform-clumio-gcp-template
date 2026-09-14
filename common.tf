provider "google" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true

  default_labels = {
    "goog-partner-solution" = local.partner_solution_urn
  }
}

provider "google-beta" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true

  default_labels = {
    "goog-partner-solution" = local.partner_solution_urn
  }
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
  # Always update the config_version when changing this file's resources; comment-only edits do
  # not bump it.
  config_version = "2.10"
  # GCP Marketplace consumption tracking label, required on the customer project resources we create.
  partner_solution_urn = "isol_plb32_0014m00001h36koqaq_shblifz2o2wmkt4vgrzqshobfivee3t2"
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

  # Distinct customer-managed encryption keys requested across regions. Used in gcs.tf to grant the
  # service agents cryptoKeyEncrypterDecrypter on each key. Deduplicated so a key shared by multiple
  # regions gets a single IAM binding per agent.
  # Built from regions_to_create_clumio_inventory_bridge_bucket (not the raw region list) so grants
  # exist only for keys attached to a bucket this template actually creates. A region that brings its
  # own bucket manages its bucket's CMEK and service-agent key access itself (enforced by a validation
  # in variables.tf that rejects setting both fields together).
  inventory_bridge_kms_keys = toset([
    for region, cfg in local.regions_to_create_clumio_inventory_bridge_bucket : trimspace(cfg.inventory_bridge_kms_key_name)
    if trimspace(cfg.inventory_bridge_kms_key_name) != ""
  ])

  # Customer-managed encryption key for the delta feed topic, normalized once here so the topic's
  # kms_key_name and the Pub/Sub service-agent grant always reference the identical key string.
  # Empty means Google-managed encryption (the default).
  delta_topic_kms_key = trimspace(var.delta_topic_kms_key_name)

  # True only when a topic is actually created and encrypted, so a key supplied alongside
  # is_gcs_enabled = false neither grants the Pub/Sub agent access nor enables the Cloud KMS API.
  delta_topic_cmek_enabled = var.is_gcs_enabled && local.delta_topic_kms_key != ""

  # Every inventory-bridge bucket, keyed by region, whether created by this template or supplied
  # by the customer. Read by the bucket-level agent grants in gcs.tf and by the region
  # configuration reported to the post-process callback below, so both always name the same
  # bucket. Buckets this template creates are referenced by resource attribute rather than a
  # rebuilt name string, so the graph orders bucket-create before those grants. Empty when GCS
  # is disabled, in which case no grant is created and no region configuration is reported.
  all_inventory_bridge_buckets = var.is_gcs_enabled ? {
    for r in var.region_configuration : r.region => (
      trimspace(r.using_custom_inventory_bridge_bucket) == ""
      ? google_storage_bucket.clumio_inventory_bridge[r.region].name
      : trimspace(r.using_custom_inventory_bridge_bucket)
    )
  } : {}

  # The same buckets re-keyed for the bucket-level grants in gcs.tf, because for_each needs its key
  # set known at plan time and a bucket NAME is not: a Clumio-created name derives from the
  # connection token, which is only known once the connection exists. So a Clumio-created bucket is
  # keyed by its region -- its name embeds the region, so two regions cannot collide -- and a
  # customer-supplied bucket is keyed by its own name, so two regions naming the same bucket
  # collapse to a single grant instead of racing two identical ones. merge keeps one entry per key,
  # and the prefixes stop a region label from ever colliding with a bucket name.
  inventory_bridge_bucket_grant_targets = var.is_gcs_enabled ? merge([
    for r in var.region_configuration : {
      (trimspace(r.using_custom_inventory_bridge_bucket) == ""
        ? "region/${r.region}"
        : "bucket/${trimspace(r.using_custom_inventory_bridge_bucket)}"
      ) = local.all_inventory_bridge_buckets[r.region]
    }
  ]...) : {}

  # Whether the module manages the GCS custom roles and their bindings. They are gated on GCS being
  # enabled; when manage_gcs_iam is false they are provisioned outside this module.
  manage_gcs_iam = var.is_gcs_enabled && var.manage_gcs_iam

  # Custom-role IDs for the GCS roles, kept in one place so they all share one token suffix and
  # the whole id set is visible at once. The bindings still read the role via [0].role_id rather
  # than through these: a local carries no dependency edge, and a binding must not be applied
  # before its role exists.
  gcs_custom_role_ids = {
    inventory = "GCSInvPermission_${local.sanitized_clumio_token}"
    backup    = "GCSBackupPermissions_${local.sanitized_clumio_token}"
    restore   = "GCSRestorePermissions_${local.sanitized_clumio_token}"
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

# Both impersonation grants predate their count gate, so existing deployments hold them at the
# un-indexed state address. Without these moves the next apply plans destroy + create for each,
# leaving Clumio unable to impersonate the customer SA between the two operations. A moved block
# whose from address is absent is a no-op, so fresh onboardings are unaffected.
moved {
  from = google_service_account_iam_member.clumio_sa_user
  to   = google_service_account_iam_member.clumio_sa_user[0]
}

moved {
  from = google_service_account_iam_member.allow_token_creator
  to   = google_service_account_iam_member.allow_token_creator[0]
}


resource "clumio_post_process_gcp_connection" "post_process" {
  depends_on = [
    google_service_account.clumio_created_sa,
    google_service_account_iam_member.clumio_sa_user,
    google_project_service.monitoring_api,
    google_project_service.storage_api,
    google_project_iam_custom_role.clumio_gcs_backup_permission,
    google_project_iam_custom_role.clumio_gcs_inventory_permission,
    google_project_iam_custom_role.clumio_gcs_restore_permission,
    google_project_iam_member.clumio_gcs_backup_permission_iam_binding,
    google_pubsub_topic_iam_member.clumio_bridge_delta_topic_subscriber,
    google_project_iam_member.clumio_gcs_inventory_permission_iam_binding,
    google_project_iam_member.clumio_gcs_restore_permission_iam_binding,
    google_pubsub_topic_iam_member.cloudasset_service_agent_pubsub_publisher,
    google_project_iam_member.storage_service_agent_pubsub_publisher,
    google_project_iam_member.storagetransfer_service_agent,
    google_project_service_identity.storageinsights,
    google_project_iam_member.insights_collector,
    # CMEK key grants must land before the callback so the first inventory-report write / STS
    # replication doesn't race ahead of the agents holding cryptoKeyEncrypterDecrypter (no-op
    # when no CMEK key is configured).
    google_kms_crypto_key_iam_member.inventory_bridge_gcs_agent_cmek,
    google_kms_crypto_key_iam_member.inventory_bridge_insights_agent_cmek,
    google_kms_crypto_key_iam_member.inventory_bridge_transfer_agent_cmek,
    google_kms_crypto_key_iam_member.delta_topic_pubsub_agent_cmek,
    google_project_service.cloudasset,
    google_storage_bucket.clumio_inventory_bridge,
    # Bucket-level agent grants must land before the callback so the first inventory-report write /
    # replication job does not race ahead of them.
    google_storage_bucket_iam_member.inventory_bridge_insights_agent_object_creator,
    google_storage_bucket_iam_member.inventory_bridge_transfer_agent_object_viewer,
    google_storage_bucket_iam_member.inventory_bridge_transfer_agent_bucket_owner,
    google_pubsub_topic.customer_delta,
    google_cloud_asset_project_feed.customer_delta,
    google_service_account_iam_member.allow_token_creator,
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
  # When GCS is disabled there are no inventory bridge buckets, so emit no region configuration
  # at all. Kept as a list over var.region_configuration rather than a comprehension over the
  # local so the reported order matches the regions list above.
  region_configuration = var.is_gcs_enabled ? [for r in var.region_configuration : {
    region                       = r.region
    inventory_bridge_bucket_name = local.all_inventory_bridge_buckets[r.region]
  }] : []
  properties = var.is_gcs_enabled ? {
    customer_delta_topic_id = google_pubsub_topic.customer_delta[0].id,
  } : {}
}
