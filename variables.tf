variable "project_id" {
  type        = string
  description = "Client GCP project Id."

  validation {
    condition     = can(regex("^([a-z0-9.-]+:)?[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id must be 6-30 characters, start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and not end with a hyphen. Legacy domain-scoped IDs (domain.com:project-id) are also accepted."
  }
}

variable "clumio_token" {
  description = <<-EOT
    Unique identifier that Clumio uses to identify this GCP connection.
    It acts as a handle for the connection rather than a credential.
  EOT

  type = string

  validation {
    condition     = trimspace(var.clumio_token) != ""
    error_message = "clumio_token must not be empty."
  }
}

variable "clumio_service_account_email" {
  description = "The email of the Clumio service account."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$", var.clumio_service_account_email))
    error_message = "clumio_service_account_email must be a valid GCP service account email (name@project.iam.gserviceaccount.com)."
  }
}

variable "customer_service_account_email" {
  description = "The email of the Customer's service account. If not provided, a service account will be created by this template. When provided, it must be a user-managed service account."
  type        = string
  default     = ""

  validation {
    condition = (
      var.customer_service_account_email == "" ||
      can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$", var.customer_service_account_email))
    )
    error_message = "customer_service_account_email must be a user-managed service account email (name@project-id.iam.gserviceaccount.com)."
  }
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
    # Optional customer-managed encryption key (CMEK) for the region's inventory-bridge bucket.
    # Leave empty (default) to use Google-managed encryption. When set, the bucket is created with
    # this key as its default encryption key, and the Cloud Storage, Storage Insights, and Storage
    # Transfer service agents are granted cryptoKeyEncrypterDecrypter on it (see gcs.tf). The key's
    # location must be compatible with the region, hence this is per-region rather than a single
    # global key. Required for customers subject to the constraints/gcp.restrictNonCmekServices
    # org policy, which otherwise rejects the bucket create.
    inventory_bridge_kms_key_name = optional(string, "")
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

  validation {
    condition = alltrue([
      for r in var.region_configuration :
      can(regex("^projects/[^/[:space:]]+/locations/[^/[:space:]]+/keyRings/[^/[:space:]]+/cryptoKeys/[^/[:space:]]+$", trimspace(r.inventory_bridge_kms_key_name)))
      if trimspace(r.inventory_bridge_kms_key_name) != ""
    ])
    error_message = "inventory_bridge_kms_key_name must be a fully-qualified Cloud KMS key resource ID that does not contain internal whitespace (projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY)."
  }

  validation {
    condition = alltrue([
      for r in var.region_configuration :
      !(trimspace(r.using_custom_inventory_bridge_bucket) != "" && trimspace(r.inventory_bridge_kms_key_name) != "")
    ])
    error_message = "inventory_bridge_kms_key_name cannot be set together with using_custom_inventory_bridge_bucket for the same region. A customer-provided bucket must have its own CMEK default key and service-agent key access configured outside this template; this template only manages CMEK for buckets it creates."
  }
}

variable "gcs_inventory_bridge_bucket_labels" {
  description = "Labels to apply to Clumio inventory bridge buckets. Use this for labels required by your organization policies."
  type        = map(string)
  default     = {}

  # Keys: 1-63 chars; lowercase letter or international letter first, then lowercase/international
  # letters, digits, underscores, and dashes.
  validation {
    condition = alltrue([
      for k, _ in var.gcs_inventory_bridge_bucket_labels :
      can(regex("^[\\p{Ll}\\p{Lo}][\\p{Ll}\\p{Lo}\\p{N}_-]{0,62}$", k))
    ])
    error_message = "Each label key must be 1-63 characters, start with a lowercase or international letter, and contain only lowercase letters, digits, underscores, dashes, and international characters."
  }

  # Values: may be empty, up to 63 chars, same allowed character set as keys.
  validation {
    condition = alltrue([
      for _, v in var.gcs_inventory_bridge_bucket_labels :
      can(regex("^[\\p{Ll}\\p{Lo}\\p{N}_-]{0,63}$", v))
    ])
    error_message = "Each label value must be at most 63 characters and contain only lowercase letters, digits, underscores, dashes, and international characters."
  }
}

# The delta feed's Pub/Sub topic is project-global (one topic per project), so its key is a single
# top-level input rather than the per-region form used by
# region_configuration.inventory_bridge_kms_key_name. Google recommends a global key for Pub/Sub
# topics because Pub/Sub resources are themselves global; a regional key works but introduces
# cross-region network dependencies for publishers and subscribers.
variable "delta_topic_kms_key_name" {
  description = <<EOT

  Optional customer-managed encryption key (CMEK) for the Clumio delta feed Pub/Sub topic.

  Leave empty (default) to use Google-managed encryption. When set, the topic is created with this
  key and the Pub/Sub service agent is granted cryptoKeyEncrypterDecrypter on it, so the deploying
  identity must be able to set IAM policy on the key (roles/cloudkms.admin, or any role granting
  cloudkms.cryptoKeys.setIamPolicy on it) - the same requirement the inventory-bridge keys carry.
  Required for customers subject to the constraints/gcp.restrictNonCmekServices org policy, which
  otherwise rejects the topic create. Ignored when is_gcs_enabled is false, since no topic is
  created.

  The template orders the key grant before the topic, but Cloud KMS IAM can take time to become
  effective. If the first apply fails the topic create with FAILED_PRECONDITION, re-run
  terraform apply.

  Rotate by adding a version to this key rather than by naming a different key. Pub/Sub does not
  re-encrypt messages already published, so replacing the key withdraws the service agent's access
  to the old one and any message still awaiting delivery under it cannot be read. Clearing this
  variable after a key has been set has the same effect: new messages revert to Google-managed
  encryption, but the grant is revoked and anything still retained under the old key becomes
  unreadable.

EOT

  type    = string
  default = ""

  validation {
    condition = (
      trimspace(var.delta_topic_kms_key_name) == "" ||
      can(regex("^projects/[^/[:space:]]+/locations/[^/[:space:]]+/keyRings/[^/[:space:]]+/cryptoKeys/[^/[:space:]]+$", trimspace(var.delta_topic_kms_key_name)))
    )
    error_message = "delta_topic_kms_key_name must be a fully-qualified Cloud KMS key resource ID that does not contain internal whitespace (projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY)."
  }
}
