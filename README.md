<!-- BEGIN_TF_DOCS -->

# Clumio GCP Terraform Module

> ⚠️ **Beta Release**
>
> This module is currently in **beta** and available only to select customers.
> Interfaces (inputs/outputs), behavior, and implementation details may change in future releases.

Terraform module to install the Clumio required GCP resources in the customer GCP account.

## Usage
This module is to be used along with the resource clumio_gcp_connection as some of the inputs for the module are obtained from the output of clumio_gcp_connection resource.
Below is an example of using the module:

```hcl
// Varifies the valid project id is the pass
data "google_project" "current" {
  project_id = var.project_id
}

# 1) Create the Clumio connection object for this AWS account+region
resource "clumio_gcp_connection" "this" {
  project_id  = data.google_project.current.project_id
  description = "Onboarded via Terraform"
}
# 2) Install GCP resources required by Clumio in your rpoject
module "clumio_gcp_connection" {
  providers = {
    clumio = clumio
  }
  source                = "../../"
  clumio_token          = clumio_gcp_connection.this.token
  project_id            = data.google_project.current.project_id
  clumio_aws_account_id = clumio_gcp_connection.this.clumio_aws_account_id
  clumio_aws_iam_role   = clumio_gcp_connection.this.clumio_aws_iam_role
  is_gcs_enabled        = true
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_clumio"></a> [clumio](#provider\_clumio) | n/a |
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [clumio_post_process_gcp_connection.post_process](https://registry.terraform.io/providers/clumio-code/clumio/latest/docs/resources/post_process_gcp_connection) | resource |
| [google_iam_workload_identity_pool.pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.aws](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_custom_role.clumio_gcs_backup_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_custom_role.clumio_gcs_cai_feed_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_custom_role.clumio_gcs_inventory_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_custom_role.clumio_gcs_restore_permission](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_member.clumio_gcs_backup_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.clumio_gcs_cai_feed_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.clumio_gcs_inventory_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.clumio_gcs_restore_permission_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.iam_credentials_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.storage_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.federated_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.allow_token_creator](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.allow_wi_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_clumio_aws_account_id"></a> [clumio\_aws\_account\_id](#input\_clumio\_aws\_account\_id) | Clumio Control Plane Account Id. | `string` | n/a | yes |
| <a name="input_clumio_aws_iam_role"></a> [clumio\_aws\_iam\_role](#input\_clumio\_aws\_iam\_role) | Clumio AWS IAM Role name that will federate into GCP | `string` | n/a | yes |
| <a name="input_clumio_federated_aws_service_account_id"></a> [clumio\_federated\_aws\_service\_account\_id](#input\_clumio\_federated\_aws\_service\_account\_id) | The name of the Clumio federated service account. | `string` | `"clumio-federated-aws-user"` | no |
| <a name="input_clumio_token"></a> [clumio\_token](#input\_clumio\_token) | The GCP integration ID token. | `string` | n/a | yes |
| <a name="input_clumio_wif_pool_id"></a> [clumio\_wif\_pool\_id](#input\_clumio\_wif\_pool\_id) | Workload Identity Pool ID | `string` | `"clumio-aws-pool"` | no |
| <a name="input_clumio_wif_provider_id"></a> [clumio\_wif\_provider\_id](#input\_clumio\_wif\_provider\_id) | Workload Identity Pool Provider ID | `string` | `"clumio-aws-provider"` | no |
| <a name="input_is_gcs_enabled"></a> [is\_gcs\_enabled](#input\_is\_gcs\_enabled) | Flag to indicate if Clumio Protect for GCS is enabled | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Client GCP project Id. | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END_TF_DOCS -->