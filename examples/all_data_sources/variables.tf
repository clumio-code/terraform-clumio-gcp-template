###############################
# Clumio Configuration
###############################
# Your Clumio API token (from the Clumio portal under Settings → API Tokens)
variable "clumio_api_token" {
  description = "The API token used to authenticate with Clumio."
  type        = string
  sensitive   = false
  default     = "eyJhbGciOiJSUzI1NiIsImtpZCI6Ik1HUTJPV0l5WXpVdFlqZGpaUzAwTURZMExUaGtabVV0WWpjelltUTJaRGt4WXpobCIsInR5cCI6IkpXVCJ9.eyJjdXN0b206bmFtZSI6InRmX3Rlc3RpbmciLCJjdXN0b206bnMiOiJ1aS0wMS11dy0yLTAyIiwiY3VzdG9tOm9yZ2lkIjoiMiIsImN1c3RvbTp1c2VyaWQiOiIzMTAiLCJpYXQiOjE3NjQwNjQzOTYsImlzcyI6Imh0dHBzOi8vdWktMDEtdXctMi0wMi1iYWNrZW5kLmFwaS51aS0wMS5jbHVtLmlvL2FwaS90b2tlbnMvb3JnYW5pemF0aW9ucy8yIiwianRpIjoiMGQ2OWIyYzUtYjdjZS00MDY0LThkZmUtYjczYmQ2ZDkxYzhlIiwic3ViIjoiL3Rva2Vucy8wZDY5YjJjNS1iN2NlLTQwNjQtOGRmZS1iNzNiZDZkOTFjOGUiLCJ0b2tlbl91c2UiOiJhY2Nlc3MifQ.R2A5vPeOCi5UdjmNsmcfU4xb9Q6HhBa6HjP0r1QZPUSVlZDR8Zr2kZAvmuRRCZKG0E18KuGu2pXt6FP54cdNf7_WsK40mtsFQXyCNpGgYGNJ3kQZRWeXS_5LAc4Fi5_KUxsuY7X1PXtSmtB3wPNjBKaWn22zKmsQ0Ihhq0KfLohIy4HssPVG-_kMW3zxZ5nTO6HVyLJLr9vM7QLnaz3zzIlAHZbBLZZ4CmkJjCoZdnoW4IgLIQ6KwQcZWSl06fWLlmSRT04ZRw6-MzXw5sa0XNyvd1NdtWc6ZXV19G1VJvwzO0nVO00Yn2suEQLT2eldLmBoQEljE_uoR9pNE2kVkQ"
}
# Clumio API endpoint for your region (examples below)
#   US West (Oregon):  https://us-west-2.api.clumio.com
#   US East (N. Virginia): https://us-east-1.api.clumio.com
#   EU (Frankfurt): https://eu-central-1.api.clumio.com
#   AU (Sydney): https://ap-southeast-2.au.api.clumio.com

variable "clumio_api_base_url" {
  description = "The base API URL for the Clumio service."
  type        = string
  default     = "https://ui-01-uw-2-02-backend.api.ui-01.clum.io/api"
}

###############################
# GCP Configuration
###############################
# GCP project ID where the Clumio integration will be deployed
variable "project_id" {
  description = "GCP project ID to create resources in"
  type        = string
  default     = "clumio-ui-01-testplane-01"
}
