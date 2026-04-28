variable "project_id" {
  description = "Client GCP project Id"
  type        = string
}

variable "clumio_control_plane_id" {
  description = "Clumio control plane Account Id"
  type        = string
}

variable "clumio_control_plane_role" {
  description = "Clumio control plane Role name that will federate into GCP"
  type        = string
}

variable "clumio_token" {
  description = "The GCP integration ID token"
  type        = string
}

variable "clumio_federated_aws_service_account_id" {
  description = "The name of the Clumio federated service account"
  type        = string
  default     = "clumio-federated-aws-user"
}

# WIF IDs (use the ones you created)
variable "clumio_wif_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "clumio-aws-pool"
}

variable "clumio_wif_provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
  default     = "clumio-aws-provider"
}

variable "is_gcs_enabled" {
  description = "Flag to indicate if Clumio Protect for GCS is enabled"
  type        = bool
  default     = false
}

variable "regions" {
  description = "List of GCP regions in which to enable Clumio backup capabilities."
  type        = list(string)
  default     = []
}

variable "gcs_inventory_bridge_bucket_mode" {
  description = "Controls whether Terraform creates Clumio inventory bridge buckets. Use skip when the buckets already exist and are managed outside this template."
  type        = string
  default     = "create"

  validation {
    condition     = contains(["create", "skip"], var.gcs_inventory_bridge_bucket_mode)
    error_message = "gcs_inventory_bridge_bucket_mode must be one of: create, skip."
  }
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}
}
