## 0.8.1
- Added four optional inputs to delegate resource management to external tooling, all defaulting to `true` so existing configurations are unaffected:
  - `manage_gcs_iam` — when `false`, the module no longer creates the Clumio GCS custom IAM roles or their bindings to the customer service account.
  - `manage_service_account_impersonation` — when `false`, the module no longer grants `roles/iam.serviceAccountTokenCreator` or `roles/iam.serviceAccountUser` to the Clumio service account on the customer service account.
  - `manage_api_enablement` — when `false`, the module no longer enables the required Google APIs (Cloud Storage, Storage Transfer, Pub/Sub, Cloud Asset, Storage Insights, Monitoring, and Cloud KMS when a CMEK key is configured).
  - `manage_service_agent_bindings` — when `false`, the module no longer materializes the Cloud Asset and Storage Insights service identities, no longer binds the roles the Storage Transfer, Cloud Storage, Cloud Asset, and Storage Insights service agents need, and no longer grants those agents CMEK key access.
- When any flag is `false`, provide an existing `customer_service_account_email` so the module can still wire the kept resources and the Clumio post-process handshake. The custom-role ids are now derived from shared locals so bindings and roles stay consistent whether or not the module manages them.
- With all four `manage_*` flags set to `false`, the module provisions only the resources still owned by the caller's platform tooling's Terraform runner: the inventory-bridge bucket, the delta Pub/Sub topic, the Cloud Asset feed, and the Clumio post-process handshake.
- Added an `examples/external_resource_management` example and plan-only `terraform test` coverage for the new flags.


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
