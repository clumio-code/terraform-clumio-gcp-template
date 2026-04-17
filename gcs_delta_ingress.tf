resource "random_id" "customer_delta_suffix" {
  count = var.is_gcs_enabled ? 1 : 0

  byte_length = 4
}

resource "google_pubsub_topic" "customer_delta" {
  count = var.is_gcs_enabled ? 1 : 0

  project = var.project_id
  name    = "clumio-gcs-bucket-delta-${random_id.customer_delta_suffix[0].hex}"

  depends_on = [google_project_service.pubsub]
}

resource "google_cloud_asset_project_feed" "customer_delta" {
  count = var.is_gcs_enabled ? 1 : 0

  project      = var.project_id
  feed_id      = "clumio-gcs-bucket-delta-${random_id.customer_delta_suffix[0].hex}"
  asset_types  = ["storage.googleapis.com/Bucket"]
  content_type = "RESOURCE"

  feed_output_config {
    pubsub_destination {
      topic = google_pubsub_topic.customer_delta[0].id
    }
  }

  depends_on = [
    google_project_service.cloudasset,
    google_project_iam_member.cloudasset_service_agent_pubsub_publisher,
    google_pubsub_topic.customer_delta,
  ]
}
