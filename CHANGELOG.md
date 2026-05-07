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
