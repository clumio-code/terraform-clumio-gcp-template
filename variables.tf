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

variable "customer_service_account_email" {
  description = "The email of the Customer's service account. If not provided, a service account will be created by this template."
  type        = string
  default     = ""
}

variable "is_gcs_enabled" {
  description = "Flag to indicate if Clumio Protect for GCS is enabled"
  type        = bool
  default     = false
}

variable "region_configuration" {
  description = <<EOT

  Per-region configuration for Clumio backup capabilities in GCP.

  Each entry defines a GCP region and whether Clumio should create the inventory bridge bucket for that region.
  Set create_clumio_inventory_bridge_bucket to false if the project is already onboarded for the region under a different Clumio account.

EOT

  type = list(object({
    region                                = string
    create_clumio_inventory_bridge_bucket = bool
  }))

  validation {
    condition     = length(var.region_configuration) > 0
    error_message = "At least one region must be specified."
  }

  validation {
    condition = alltrue([
      for r in var.region_configuration : trimspace(r.region) != ""
    ])
    error_message = "Each region must have a non-empty region value."
  }

  validation {
    condition = length(var.region_configuration) == length(distinct([
      for r in var.region_configuration : trimspace(r.region)
    ]))
    error_message = "Each region must be unique."
  }
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}
}
