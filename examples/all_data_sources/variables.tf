###############################
# Clumio Configuration
###############################
# Your Clumio API token (from the Clumio portal under Settings → API Tokens)
variable "clumio_api_token" {
  description = "The API token used to authenticate with Clumio"
  type        = string
  sensitive   = true
}
# Clumio API endpoint for your region (examples below)
#   US West (Oregon):  https://us-west-2.api.clumio.com
#   US East (N. Virginia): https://us-east-1.api.clumio.com
#   EU (Frankfurt): https://eu-central-1.api.clumio.com
#   AU (Sydney): https://ap-southeast-2.au.api.clumio.com
#   CA (Central): https://ca-central-1.ca.api.clumio.com

variable "clumio_api_base_url" {
  description = "The base API URL for the Clumio service"
  type        = string
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
  description = "List of GCP regions in which to enable Clumio backup capabilities. Clumio currently supports backup of GCP resources in us-central1, and us-west1"
  type        = list(string)
  default     = ["us-central1", "us-west1"]
}

variable "is_gcs_enabled" {
  description = "Flag to indicate if Clumio Protect for GCS is enabled"
  type        = bool
  default     = true
}

variable "create_clumio_inventory_bridge_bucket" {
  description = "Indicates that Clumio inventory bridge buckets must be created by this template. Set to false when the buckets already exist and are managed outside this template."
  type        = bool
  default     = true
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Description for the Clumio integration"
  type        = string
  default     = "Onboarded via Terraform"
}

# The Clumio-side service account that is granted permission to impersonate the
# customer service account created by this module. Obtain this value from the
# Clumio portal (or the clumio_gcp_connection resource once provider support for
# the impersonation model is released).
variable "clumio_service_account_email" {
  description = "The email of the Clumio service account."
  type        = string
}

###############################
# Optional configuration
###############################

variable "deployment_type" {
  description = "How the GCP connection template is deployed. Allowed values: \"direct_terraform\", \"infrastructure_manager\""
  type        = string
  default     = "direct_terraform"

  validation {
    condition     = contains(["direct_terraform", "infrastructure_manager"], var.deployment_type)
    error_message = "deployment_type must be one of: \"direct_terraform\", \"infrastructure_manager\"."
  }
}
