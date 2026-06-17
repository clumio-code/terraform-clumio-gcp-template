## 0.4.0

- Migrated GCP onboarding to the service-account impersonation model: the customer project now creates a customer-side service account that the Clumio service account impersonates, and the Workload Identity Federation pool/provider are managed by Clumio rather than by this module.
- Replaced the `clumio_control_plane_id`, `clumio_control_plane_role`, `clumio_federated_aws_service_account_id`, `clumio_wif_pool_id`, and `clumio_wif_provider_id` inputs with `clumio_service_account_email`.
- Scoped GCS bucket IAM-policy management to Clumio inventory-bridge buckets and dropped unused backup, restore, Storage Transfer, monitoring, and Storage Insights permissions.
- Removed the unused GCS Cloud Asset Inventory feed permission role.
- Granted the Storage Insights service agent project-level access for inventory report generation.
- Added the optional `customer_service_account_email` input: when set, the module uses the customer-provided service account instead of creating one.
- `create_clumio_inventory_bridge_bucket` and `regions` are now required inputs.
- Bumped the required Clumio provider to `>= 0.21.0`.

## 0.3.0-beta

- Added GCS bucket change tracking support for protection workflows.
- Added optional Terraform-managed Clumio inventory bridge buckets with configurable regions and labels.
- Improved GCS setup by enabling required Google Cloud services and updating permissions.
- Improved service account IAM management to preserve existing role members.
- Updated provider requirements, including Clumio provider `>= 0.19.0`.

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
