variable "project_id" {
  description = "Client GCP project Id."
  type        = string
}

variable "clumio_token" {
  description = "The GCP integration ID token."
  type        = string
}

variable "clumio_service_account_email" {
  description = "The email of the Clumio service account."
  type        = string
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

variable "create_clumio_inventory_bridge_bucket" {
  description = "Set to false if the project is already onboarded for this region under a different Clumio account."
  type        = bool
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}
}
