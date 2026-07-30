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

  Each entry defines a GCP region and, optionally, an existing inventory bridge bucket for that region.
  Leave using_custom_inventory_bridge_bucket empty (default) to have Clumio create the inventory bridge
  bucket. Set it to the name of an existing bucket to have Clumio use that bucket instead; in that case no
  bucket is created for the region.

EOT

  type = list(object({
    region                               = string
    using_custom_inventory_bridge_bucket = optional(string, "")
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

  validation {
    condition = alltrue([
      for r in var.region_configuration :
      can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", r.using_custom_inventory_bridge_bucket))
      if trimspace(r.using_custom_inventory_bridge_bucket) != ""
    ])
    error_message = "using_custom_inventory_bridge_bucket must be a valid GCS bucket name (3-63 chars, lowercase letters, numbers, '-', '_', '.', starting and ending with a letter or number)."
  }
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}
}
