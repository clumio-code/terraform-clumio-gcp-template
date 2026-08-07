# Plan-only tests for the optional IAM-delegation feature flags.
#
# These tests use mock providers so they run without GCP or Clumio credentials
# (`terraform test`). They assert how many of the module's optional resources are planned under
# different flag combinations, verifying that:
#   - defaults preserve the original behavior (all IAM managed by the module), and
#   - the flags let an external system own the roles, bindings and impersonation grants.

mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "clumio" {}
mock_provider "random" {}

variables {
  project_id                   = "example-project"
  clumio_token                 = "clumio-token-1234-5678"
  clumio_service_account_email = "clumio@clumio-prod.iam.gserviceaccount.com"
  is_gcs_enabled               = true
  region_configuration = [
    { region = "us-west1" },
  ]
}

# Default behavior: the module manages the SA, impersonation, custom roles and bindings.
run "defaults_manage_all_iam" {
  command = plan

  # SA is created because no customer_service_account_email is provided.
  assert {
    condition     = length(google_service_account.clumio_created_sa) == 1
    error_message = "Expected the module to create the customer service account by default."
  }

  # Both impersonation grants are managed by default.
  assert {
    condition     = length(google_service_account_iam_member.allow_token_creator) == 1
    error_message = "Expected the token-creator impersonation grant by default."
  }
  assert {
    condition     = length(google_service_account_iam_member.clumio_sa_user) == 1
    error_message = "Expected the service-account-user impersonation grant by default."
  }

  # All six custom roles are managed by default.
  assert {
    condition     = length(google_project_iam_custom_role.clumio_gcs_backup_permission) == 1
    error_message = "Expected the backup custom role by default."
  }

  # All six role bindings are managed by default.
  assert {
    condition     = length(google_project_iam_member.clumio_gcs_backup_permission_iam_binding) == 1
    error_message = "Expected the backup role binding by default."
  }
}

# Delegated IAM: external tooling owns the SA, impersonation, roles and bindings.
run "delegated_iam_management" {
  command = plan

  variables {
    customer_service_account_email       = "clumio-customer@example-project.iam.gserviceaccount.com"
    manage_gcs_iam                       = false
    manage_service_account_impersonation = false
  }

  # No SA is created because an existing one is provided.
  assert {
    condition     = length(google_service_account.clumio_created_sa) == 0
    error_message = "Expected no service account to be created when one is provided."
  }

  # No impersonation grants when delegated.
  assert {
    condition     = length(google_service_account_iam_member.allow_token_creator) == 0
    error_message = "Expected no token-creator grant when impersonation is delegated."
  }
  assert {
    condition     = length(google_service_account_iam_member.clumio_sa_user) == 0
    error_message = "Expected no service-account-user grant when impersonation is delegated."
  }

  # No custom roles when delegated.
  assert {
    condition = alltrue([
      length(google_project_iam_custom_role.clumio_gcs_inventory_permission) == 0,
      length(google_project_iam_custom_role.clumio_gcs_backup_permission) == 0,
      length(google_project_iam_custom_role.clumio_gcs_bucket_iam_policy_permission) == 0,
      length(google_project_iam_custom_role.clumio_gcs_restore_permission) == 0,
      length(google_project_iam_custom_role.clumio_delta_topic_permission) == 0,
      length(google_project_iam_custom_role.clumio_delta_federated_sa_policy_permission) == 0,
    ])
    error_message = "Expected no custom roles when manage_gcs_iam is false."
  }

  # No role bindings when delegated.
  assert {
    condition = alltrue([
      length(google_project_iam_member.clumio_gcs_inventory_permission_iam_binding) == 0,
      length(google_project_iam_member.clumio_gcs_backup_permission_iam_binding) == 0,
      length(google_project_iam_member.clumio_gcs_bucket_iam_policy_permission_iam_binding) == 0,
      length(google_project_iam_member.clumio_gcs_restore_permission_iam_binding) == 0,
      length(google_pubsub_topic_iam_member.clumio_delta_topic_permission_iam_binding) == 0,
      length(google_service_account_iam_member.clumio_delta_federated_sa_policy_permission_iam_binding) == 0,
    ])
    error_message = "Expected no role bindings when manage_gcs_iam is false."
  }

  # Kept resources are still managed by the module even when IAM is delegated.
  assert {
    condition     = length(google_pubsub_topic.customer_delta) == 1
    error_message = "Expected the delta Pub/Sub topic to still be managed by the module."
  }
  assert {
    condition     = length(google_project_service.storage_api) == 1
    error_message = "Expected the module to still enable the Storage API."
  }
}

# Roles/bindings can be delegated independently of impersonation.
run "delegate_roles_keep_impersonation" {
  command = plan

  variables {
    manage_gcs_iam                       = false
    manage_service_account_impersonation = true
  }

  assert {
    condition     = length(google_project_iam_custom_role.clumio_gcs_backup_permission) == 0
    error_message = "Expected no custom roles when manage_gcs_iam is false."
  }
  assert {
    condition     = length(google_service_account_iam_member.allow_token_creator) == 1
    error_message = "Expected impersonation grants to remain when only manage_gcs_iam is false."
  }
}
