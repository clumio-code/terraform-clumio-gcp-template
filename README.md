<!-- BEGIN_TF_DOCS -->

# Clumio GCP Terraform Module

Terraform module to install the Clumio required GCP resources in the customer GCP account.

## Usage
This module is to be used along with the resource clumio_gcp_connection as some of the inputs for the module are obtained from the output of clumio_gcp_connection resource.
Below is an example of using the module:

```hcl
// Verifies that a valid project id is passed
data "google_project" "current" {
  project_id = var.project_id
}

# 1) Create the Clumio connection object for this GCP project
resource "clumio_gcp_connection" "this" {
  project_id      = data.google_project.current.project_id
  description     = var.description
  regions         = [for r in var.region_configuration : r.region]
  deployment_type = var.deployment_type
}
# 2) Install GCP resources required by Clumio in your project
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source = "../../"

  clumio_token                   = clumio_gcp_connection.this.token
  project_id                     = data.google_project.current.project_id
  region_configuration           = var.region_configuration
  clumio_service_account_email   = clumio_gcp_connection.this.clumio_service_account
  is_gcs_enabled                 = var.is_gcs_enabled
  customer_service_account_email = var.customer_service_account_email
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_clumio"></a> [clumio](#requirement\_clumio) | >= 0.22.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 8.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 5.39, < 8.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_clumio"></a> [clumio](#provider\_clumio) | >= 0.22.0 |
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0, < 8.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >= 5.39, < 8.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [clumio_post_process_gcp_connection.post_process](https://registry.terraform.io/providers/clumio-code/clumio/latest/docs/resources/post_process_gcp_connection) | resource |
| [google-beta_google_project_service_identity.cloudasset](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google-beta_google_project_service_identity.pubsub](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google-beta_google_project_service_identity.storageinsights](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_cloud_asset_project_feed.customer_delta](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_asset_project_feed) | resource |
| [google_kms_crypto_key_iam_member.delta_topic_pubsub_agent_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.inventory_bridge_gcs_agent_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.inventory_bridge_insights_agent_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.inventory_bridge_transfer_agent_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_project_iam_custom_role.clumio_gcs_backup_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_custom_role.clumio_gcs_inventory_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_custom_role.clumio_gcs_restore_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_member.clumio_gcs_backup_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.clumio_gcs_inventory_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.clumio_gcs_restore_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.insights_collector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.storage_service_agent_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.storagetransfer_service_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.cloudasset](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.cloudkms](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.monitoring_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.pubsub](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.storage_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.storageinsights](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.storagetransfer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_topic.customer_delta](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.cloudasset_service_agent_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_pubsub_topic_iam_member.clumio_bridge_delta_topic_subscriber](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_service_account.clumio_created_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.allow_token_creator](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.clumio_sa_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.clumio_inventory_bridge](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.inventory_bridge_insights_agent_object_creator](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.inventory_bridge_transfer_agent_bucket_owner](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.inventory_bridge_transfer_agent_object_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [random_id.customer_delta_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_service_account.customer_provided_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account) | data source |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |
| [google_storage_transfer_project_service_account.storagetransfer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_transfer_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_clumio_service_account_email"></a> [clumio\_service\_account\_email](#input\_clumio\_service\_account\_email) | The email of the Clumio service account. | `string` | n/a | yes |
| <a name="input_clumio_token"></a> [clumio\_token](#input\_clumio\_token) | Unique identifier that Clumio uses to identify this GCP connection.<br/>It acts as a handle for the connection rather than a credential. | `string` | n/a | yes |
| <a name="input_customer_service_account_email"></a> [customer\_service\_account\_email](#input\_customer\_service\_account\_email) | The email of the Customer's service account. If not provided, a service account will be created by this template. When provided, it must be a user-managed service account. | `string` | `""` | no |
| <a name="input_delta_topic_kms_key_name"></a> [delta\_topic\_kms\_key\_name](#input\_delta\_topic\_kms\_key\_name) | Optional customer-managed encryption key (CMEK) for the Clumio delta feed Pub/Sub topic.<br/><br/>  Leave empty (default) to use Google-managed encryption. When set, the topic is created with this<br/>  key and the Pub/Sub service agent is granted cryptoKeyEncrypterDecrypter on it, so the deploying<br/>  identity must be able to set IAM policy on the key (roles/cloudkms.admin, or any role granting<br/>  cloudkms.cryptoKeys.setIamPolicy on it) - the same requirement the inventory-bridge keys carry.<br/>  Required for customers subject to the constraints/gcp.restrictNonCmekServices org policy, which<br/>  otherwise rejects the topic create. Ignored when is\_gcs\_enabled is false, since no topic is<br/>  created.<br/><br/>  The template orders the key grant before the topic, but Cloud KMS IAM can take time to become<br/>  effective. If the first apply fails the topic create with FAILED\_PRECONDITION, re-run<br/>  terraform apply.<br/><br/>  Rotate by adding a version to this key rather than by naming a different key. Pub/Sub does not<br/>  re-encrypt messages already published, so replacing the key withdraws the service agent's access<br/>  to the old one and any message still awaiting delivery under it cannot be read. Clearing this<br/>  variable after a key has been set has the same effect: new messages revert to Google-managed<br/>  encryption, but the grant is revoked and anything still retained under the old key becomes<br/>  unreadable. | `string` | `""` | no |
| <a name="input_gcs_inventory_bridge_bucket_labels"></a> [gcs\_inventory\_bridge\_bucket\_labels](#input\_gcs\_inventory\_bridge\_bucket\_labels) | Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies. | `map(string)` | `{}` | no |
| <a name="input_is_gcs_enabled"></a> [is\_gcs\_enabled](#input\_is\_gcs\_enabled) | Flag to indicate if Clumio Protect for GCS is enabled | `bool` | `false` | no |
| <a name="input_manage_gcs_iam"></a> [manage\_gcs\_iam](#input\_manage\_gcs\_iam) | Whether this module manages the Clumio GCS custom IAM roles and their bindings to the customer<br/>  service account.<br/><br/>  Defaults to true, preserving the module's original behavior. Set to false when the custom roles<br/>  and role bindings are provisioned outside this module (for example by your own platform tooling),<br/>  in which case the module creates neither the `google_project_iam_custom_role` resources nor the<br/>  corresponding IAM bindings. This has no effect unless `is_gcs_enabled` is true.<br/><br/>  Intended to be set once, at onboarding time. Flipping it to false on an existing deployment<br/>  destroys the roles and bindings on the next apply, and GCP reserves a deleted custom role's id<br/>  for a soft-delete window, so external tooling cannot immediately recreate the same ids. | `bool` | `true` | no |
| <a name="input_manage_service_account_impersonation"></a> [manage\_service\_account\_impersonation](#input\_manage\_service\_account\_impersonation) | Whether this module grants the Clumio service account impersonation of the customer service<br/>  account, i.e. the `roles/iam.serviceAccountTokenCreator` and `roles/iam.serviceAccountUser`<br/>  bindings on the customer service account.<br/><br/>  Defaults to true, preserving the module's original behavior. Set to false when these impersonation<br/>  grants are provisioned outside this module (for example by your own platform tooling).<br/><br/>  Intended to be set once, at onboarding time. Flipping it to false on an existing deployment<br/>  destroys both grants on the next apply, cutting off Clumio's access to the customer service<br/>  account until they are recreated externally. | `bool` | `true` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Client GCP project Id. | `string` | n/a | yes |
| <a name="input_region_configuration"></a> [region\_configuration](#input\_region\_configuration) | Per-region configuration for Clumio backup capabilities in GCP.<br/><br/>  Each entry defines a GCP region and, optionally, an existing inventory bridge bucket for that region.<br/>  Leave using\_custom\_inventory\_bridge\_bucket empty (default) to have Clumio create the inventory bridge<br/>  bucket. Set it to the name of an existing bucket to have Clumio use that bucket instead; in that case no<br/>  bucket is created for the region. | <pre>list(object({<br/>    region                               = string<br/>    using_custom_inventory_bridge_bucket = optional(string, "")<br/>    # Optional customer-managed encryption key (CMEK) for the region's inventory-bridge bucket.<br/>    # Leave empty (default) to use Google-managed encryption. When set, the bucket is created with<br/>    # this key as its default encryption key, and the Cloud Storage, Storage Insights, and Storage<br/>    # Transfer service agents are granted cryptoKeyEncrypterDecrypter on it (see gcs.tf). The key's<br/>    # location must be compatible with the region, hence this is per-region rather than a single<br/>    # global key. Required for customers subject to the constraints/gcp.restrictNonCmekServices<br/>    # org policy, which otherwise rejects the bucket create.<br/>    inventory_bridge_kms_key_name = optional(string, "")<br/>  }))</pre> | n/a | yes |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
