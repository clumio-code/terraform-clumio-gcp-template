## 0.9.0

- Added optional customer-managed encryption key (CMEK) support for the Clumio delta feed Pub/Sub topic via the new `delta_topic_kms_key_name` variable. The template grants the Pub/Sub service agent access to the key.
- Added input validation for `project_id`, `clumio_token`, `clumio_service_account_email`, `customer_service_account_email`, and the inventory bridge bucket labels.
- Enabled the Storage Transfer and Storage Insights APIs only when `is_gcs_enabled` is true.
- Constrained the Google provider to `< 8.0` and raised the Google Beta provider requirement to `>= 5.39, < 8.0`.
- Added `manage_gcs_iam` and `manage_service_account_impersonation` flags, both defaulting to `true`. Set one to `false` to skip the template's GCS custom roles and bindings, or its service account impersonation grants, when your own tooling manages that IAM.
- Set the minimum Terraform version to `1.3`.
- Bumped the config template version to `2.7` and the GCS template version to `1.15`.

## 0.8.0

- Added optional customer-managed encryption key (CMEK) support for Clumio-created inventory bridge buckets via the new `inventory_bridge_kms_key_name` field of `region_configuration`. The template grants the required service agents access to the key.
- Reduced service agent permissions: Cloud Asset now publishes only to the Clumio delta topic, and Storage Transfer uses its service agent role instead of `roles/pubsub.editor`.
- Tightened the Cloud Monitoring permissions of the Clumio inventory and backup custom roles.
- Enforced uniform bucket-level access and disabled soft delete on Clumio-created inventory bridge buckets.
- Removed the self-referential IAM policy custom role and binding from the Clumio delta service account.
- Bumped the config template version to `2.4` and the GCS template version to `1.12`.

## 0.7.0

- Replaced the `create_clumio_inventory_bridge_bucket` field of `region_configuration` with `using_custom_inventory_bridge_bucket`, an optional bucket name. Leave it empty to have Clumio create the inventory bridge bucket for the region, or set it to an existing bucket to have Clumio use that bucket instead.
- Changed the Clumio-created inventory bridge bucket name suffix from the project ID to a hash of the Clumio token.
- Renamed the GCS delta resources and custom IAM roles to `clumio_delta_*`, and the Pub/Sub topic and Cloud Asset Inventory feed to `clumio-delta-*`. Applying this release replaces those resources.
- Scoped the bucket IAM policy role to customer-provided inventory bridge buckets in addition to Clumio-created ones.
- Bumped the config template version to `2.2` and the GCS template version to `1.8`.

## 0.6.0

- Replaced the `regions` and `create_clumio_inventory_bridge_bucket` inputs with a single `region_configuration` input, a list of `{ region, create_clumio_inventory_bridge_bucket }` objects, allowing per-region control of inventory bridge bucket creation. This is a breaking change: existing configurations must move their `regions` and `create_clumio_inventory_bridge_bucket` values into `region_configuration`.
- Required the Clumio provider `>= 0.22.0`.

## 0.5.0

- Expanded GCS backup permissions for Storage Transfer Service job management.
- Bumped GCS template version to `1.7`.
- Minor documentation updates to the `examples/all_data_sources` example.

## 0.4.0

- Switched GCP onboarding to the service-account impersonation model. Replaced the Workload Identity Federation inputs with `clumio_service_account_email`, and added the optional `customer_service_account_email` to use an existing service account.
- Tightened the GCS IAM roles to least privilege and removed the unused Cloud Asset Inventory feed role.
- Made `create_clumio_inventory_bridge_bucket` and `regions` required inputs.
- Required the Clumio provider `>= 0.21.0`.

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
