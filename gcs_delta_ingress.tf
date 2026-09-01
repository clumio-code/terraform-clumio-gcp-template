resource "random_id" "customer_delta_suffix" {
  count = var.is_gcs_enabled ? 1 : 0

  byte_length = 4
}

resource "google_pubsub_topic" "customer_delta" {
  count = var.is_gcs_enabled ? 1 : 0

  project = var.project_id
  name    = "clumio-delta-${random_id.customer_delta_suffix[0].hex}"

  # Optional customer-managed encryption key (CMEK). null when delta_topic_kms_key_name is empty,
  # in which case the topic uses Google-managed encryption. When set, the Pub/Sub service agent must
  # already hold cryptoKeyEncrypterDecrypter on the key (see google_kms_crypto_key_iam_member in
  # gcs.tf and the depends_on below) or publishes fail with FAILED_PRECONDITION.
  kms_key_name = local.delta_topic_kms_key != "" ? local.delta_topic_kms_key : null

  depends_on = [
    google_project_service.pubsub,
    google_kms_crypto_key_iam_member.delta_topic_pubsub_agent_cmek,
  ]
}

resource "google_cloud_asset_project_feed" "customer_delta" {
  count = var.is_gcs_enabled ? 1 : 0

  project      = var.project_id
  feed_id      = "clumio-delta-${random_id.customer_delta_suffix[0].hex}"
  asset_types  = ["storage.googleapis.com/Bucket"]
  content_type = "RESOURCE"

  feed_output_config {
    pubsub_destination {
      topic = google_pubsub_topic.customer_delta[0].id
    }
  }

  depends_on = [
    google_project_service.cloudasset,
    google_pubsub_topic_iam_member.cloudasset_service_agent_pubsub_publisher,
    google_pubsub_topic.customer_delta,
  ]
}
