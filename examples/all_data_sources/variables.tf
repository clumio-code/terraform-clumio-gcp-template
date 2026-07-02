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
  default     = "Onboarded via Terraform"
}

###############################
# GCP Configuration
###############################
# GCP project ID where the Clumio integration will be deployed
variable "project_id" {
  description = "GCP project ID to create resources in"
  type        = string
}

variable "regions" {
  description = "List of GCP regions in which to enable Clumio backup capabilities. Clumio currently supports backup of GCP resources in us-central1, and us-west1."
  type        = list(string)
  default     = ["us-west1", "us-central1"]
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
variable "customer_service_account_email" {
  description = "The email of the Customer's service account."
  type        = string
  default     = ""
}

variable "create_clumio_inventory_bridge_bucket" {
  description = "Set to false if the project is already onboarded for this region under a different Clumio account."
  type        = bool
  default     = true
}
