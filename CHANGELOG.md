## 0.3.0-beta

- Add GCS delta ingestion support via Cloud Asset Inventory feeds and a dedicated Pub/Sub topic for bucket change notifications.
- Enable the Cloud Asset API and grant its service agent Pub/Sub publisher permissions.
- Add custom IAM roles for delta topic management and federated service account policy management.
- Add `storage.buckets.update` and `cloudasset.assets.exportResource` to existing GCS backup and CAI feed permissions.
- Add `google-beta` and `random` provider requirements; bump minimum Clumio provider version to `>= 0.19.0`.
- Add `deployment_type` and `regions` variables for the Clumio GCP connection resource.
- Pass the customer delta topic ID to the Clumio post-process connection via the new `properties` attribute.
- Add optional Terraform-managed GCS inventory bridge buckets with configurable labels.

## 0.2.0-beta

- Enable the customer-project Monitoring and Pub/Sub APIs required for GCS protection workflows.
- Grant Pub/Sub roles to the Google Cloud Storage and Storage Transfer service agents.
- Expand Clumio GCS backup permissions to cover bucket IAM policy updates, object insights access, Storage Transfer job management, and monitoring metric reads.
- Expand Clumio GCS inventory permissions to include monitoring metric access used for bucket metrics collection.

## 0.1.0-beta

Initial beta release of the Clumio GCP Terraform module.

### Features

- Initial GCP integration support
- Service account creation and configuration
- IAM role and permission setup for Clumio
- Example configurations for module usage

### Notes

- This is a beta release. APIs and configurations may change.
- Please contact support@clumio.com for feedback and issues.
