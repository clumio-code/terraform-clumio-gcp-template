###############################
# Clumio Configuration
###############################
# Your Clumio API token (from the Clumio portal under Settings → API Tokens)
variable "clumio_api_token" {
  description = "The API token used to authenticate with Clumio."
  type        = string
  sensitive   = true
}
# Clumio API endpoint for your region (examples below)
#   US West (Oregon):  https://us-west-2.api.clumio.com
#   US East (N. Virginia): https://us-east-1.api.clumio.com
#   EU (Frankfurt): https://eu-central-1.api.clumio.com
#   AU (Sydney): https://ap-southeast-2.au.api.clumio.com

variable "clumio_api_base_url" {
  description = "The base API URL for the Clumio service."
  type        = string
}

variable "description" {
  description = "Description for the Clumio integration"
  type        = string
  default     = "Onboarded via Terraform (external IAM management)"
}

###############################
# GCP Configuration
###############################
# GCP project ID where the Clumio integration will be deployed
variable "project_id" {
  description = "GCP project ID to create resources in"
  type        = string
}

variable "region_configuration" {
  description = "List of GCP regions to enable for Clumio backup, and optionally an existing inventory bridge bucket to use for each. Leave using_custom_inventory_bridge_bucket empty to have Clumio create the bucket. Clumio currently supports us-central1 and us-west1."
  type = list(object({
    region                               = string
    using_custom_inventory_bridge_bucket = optional(string, "")
  }))
  default = [
    { region = "us-west1" },
    { region = "us-central1" },
  ]
}

variable "deployment_type" {
  description = "How the GCP connection template is deployed. Allowed values: \"direct_terraform\", \"infrastructure_manager\"."
  type        = string
  default     = "direct_terraform"

  validation {
    condition     = contains(["direct_terraform", "infrastructure_manager"], var.deployment_type)
    error_message = "deployment_type must be one of: \"direct_terraform\", \"infrastructure_manager\"."
  }
}

variable "is_gcs_enabled" {
  description = "Flag to indicate if Clumio Protect for GCS is enabled"
  type        = bool
  default     = true
}

# Required in this example: the roles, bindings and impersonation grants are managed externally, so
# the customer service account must already exist and be supplied here.
variable "customer_service_account_email" {
  description = "The email of the externally-managed customer service account that Clumio impersonates."
  type        = string

  validation {
    condition     = trimspace(var.customer_service_account_email) != ""
    error_message = "customer_service_account_email is required when IAM is managed outside the module."
  }
}
