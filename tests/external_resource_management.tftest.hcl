# Plan-only tests for the optional IAM-delegation feature flags.
#
# These tests use mock providers so they run without GCP or Clumio credentials
# (`terraform test`). They assert how many of the module's optional resources are planned under
# different flag combinations, verifying that:
#   - defaults preserve the original behavior (all IAM managed by the module), and
#   - the flags let an external system own the roles, bindings and impersonation grants.

mock_provider "google" {
  # The service-account data sources feed their `.member` into google_project_iam_member, which
  # validates the IAM member format. Pin the mocked values to valid `serviceAccount:` members so the
  # plan is accepted; the default random mock strings are not valid IAM members.
  mock_data "google_storage_transfer_project_service_account" {
    defaults = {
      member = "serviceAccount:project-000@storage-transfer-service.iam.gserviceaccount.com"
    }
  }
  mock_data "google_storage_project_service_account" {
    defaults = {
      member = "serviceAccount:service-000@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
}
mock_provider "google-beta" {
  # google_project_service_identity.* are google-beta resources; pin their member too.
  mock_resource "google_project_service_identity" {
    defaults = {
      member = "serviceAccount:service-000@example.iam.gserviceaccount.com"
    }
  }
}
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

  # API enablement is managed by default.
  assert {
    condition = alltrue([
      length(google_project_service.storage_api) == 1,
      length(google_project_service.storagetransfer) == 1,
      length(google_project_service.pubsub) == 1,
      length(google_project_service.cloudasset) == 1,
      length(google_project_service.storageinsights) == 1,
      length(google_project_service.monitoring_api) == 1,
    ])
    error_message = "Expected the module to enable all required Google APIs by default."
  }

  # Service identities and agent bindings are managed by default.
  assert {
    condition = alltrue([
      length(google_project_service_identity.cloudasset) == 1,
      length(google_project_service_identity.storageinsights) == 1,
      length(google_project_iam_member.storagetransfer_service_agent) == 1,
      length(google_project_iam_member.storage_service_agent_pubsub_publisher) == 1,
      length(google_pubsub_topic_iam_member.cloudasset_service_agent_pubsub_publisher) == 1,
      length(google_project_iam_member.insights_collector) == 1,
    ])
    error_message = "Expected the module to materialize service identities and agent bindings by default."
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

# API enablement can be delegated independently; agents and IAM stay managed.
run "delegate_api_enablement" {
  command = plan

  variables {
    manage_api_enablement = false
  }

  # No google_project_service resources when API enablement is delegated.
  assert {
    condition = alltrue([
      length(google_project_service.storage_api) == 0,
      length(google_project_service.storagetransfer) == 0,
      length(google_project_service.pubsub) == 0,
      length(google_project_service.cloudasset) == 0,
      length(google_project_service.storageinsights) == 0,
      length(google_project_service.monitoring_api) == 0,
    ])
    error_message = "Expected no API-enablement resources when manage_api_enablement is false."
  }

  # Agents and roles are unaffected by the API flag.
  assert {
    condition     = length(google_project_iam_member.storagetransfer_service_agent) == 1
    error_message = "Expected service-agent bindings to remain when only manage_api_enablement is false."
  }
  assert {
    condition     = length(google_project_iam_custom_role.clumio_gcs_backup_permission) == 1
    error_message = "Expected custom roles to remain when only manage_api_enablement is false."
  }
}

# Service agents/identities (and their CMEK grants) can be delegated independently.
run "delegate_service_agent_bindings" {
  command = plan

  variables {
    manage_service_agent_bindings = false
    region_configuration = [
      {
        region                        = "us-west1"
        inventory_bridge_kms_key_name = "projects/p/locations/us-west1/keyRings/r/cryptoKeys/k"
      },
    ]
  }

  # No service identities or agent bindings when delegated.
  assert {
    condition = alltrue([
      length(google_project_service_identity.cloudasset) == 0,
      length(google_project_service_identity.storageinsights) == 0,
      length(google_project_iam_member.storagetransfer_service_agent) == 0,
      length(google_project_iam_member.storage_service_agent_pubsub_publisher) == 0,
      length(google_pubsub_topic_iam_member.cloudasset_service_agent_pubsub_publisher) == 0,
      length(google_project_iam_member.insights_collector) == 0,
    ])
    error_message = "Expected no service identities or agent bindings when manage_service_agent_bindings is false."
  }

  # CMEK grants target the service agents, so they are also delegated (empty for_each) even though a
  # CMEK key is configured.
  assert {
    condition = alltrue([
      length(google_kms_crypto_key_iam_member.inventory_bridge_gcs_agent_cmek) == 0,
      length(google_kms_crypto_key_iam_member.inventory_bridge_insights_agent_cmek) == 0,
      length(google_kms_crypto_key_iam_member.inventory_bridge_transfer_agent_cmek) == 0,
    ])
    error_message = "Expected no agent CMEK grants when manage_service_agent_bindings is false."
  }

  # APIs, roles and the kept resources are unaffected by the agent flag.
  assert {
    condition     = length(google_project_service.storage_api) == 1
    error_message = "Expected API enablement to remain when only manage_service_agent_bindings is false."
  }
  assert {
    condition     = length(google_storage_bucket.clumio_inventory_bridge) == 1
    error_message = "Expected the inventory-bridge bucket to remain when only manage_service_agent_bindings is false."
  }
}

# Everything delegatable is delegated at once: the module manages only the resources the RaCS
# service still owns (bucket, topic, feed, post-process).
run "delegate_everything" {
  command = plan

  variables {
    customer_service_account_email       = "clumio-customer@example-project.iam.gserviceaccount.com"
    manage_gcs_iam                       = false
    manage_service_account_impersonation = false
    manage_api_enablement                = false
    manage_service_agent_bindings        = false
  }

  assert {
    condition = alltrue([
      length(google_project_service.storage_api) == 0,
      length(google_project_iam_member.storagetransfer_service_agent) == 0,
      length(google_project_iam_custom_role.clumio_gcs_backup_permission) == 0,
      length(google_service_account_iam_member.allow_token_creator) == 0,
    ])
    error_message = "Expected all delegatable resources to be absent when everything is delegated."
  }

  # The module still manages the resources RaCS runs it for.
  assert {
    condition = alltrue([
      length(google_pubsub_topic.customer_delta) == 1,
      length(google_cloud_asset_project_feed.customer_delta) == 1,
      length(google_storage_bucket.clumio_inventory_bridge) == 1,
    ])
    error_message = "Expected the bucket, topic and feed to remain module-managed when everything else is delegated."
  }
}
