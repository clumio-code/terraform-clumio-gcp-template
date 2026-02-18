variable "project_id" {
  description = "Client GCP project Id."
  type        = string
}

variable "clumio_aws_account_id" {
  description = "Clumio Control Plane Account Id."
  type        = string
}

variable "clumio_aws_iam_role" {
  description = "Clumio AWS IAM Role name that will federate into GCP"
  type        = string
}

variable "clumio_token" {
  description = "The GCP integration ID token."
  type        = string
}

variable "clumio_federated_aws_service_account_id" {
  description = "The name of the Clumio federated service account."
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
