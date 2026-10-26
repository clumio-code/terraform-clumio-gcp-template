# Security

## Reporting a Vulnerability

If you discover a potential security issue in this project we ask that you notify Clumio directly via email to support@clumio.com. Please do not create a public GitHub issue.

## Trust Model and Shared Responsibility

This module grants Clumio standing access to data in your GCP project. This section states what that access is, how to narrow or revoke it, and what stays behind after you offboard, so you can make an informed risk decision before you apply it.

### How Clumio accesses your project

- Clumio operates from its own service account, passed in as `clumio_service_account_email` (the `clumio_service_account` output of the `clumio_gcp_connection` resource).
- The module grants that account `roles/iam.serviceAccountTokenCreator` and `roles/iam.serviceAccountUser` on a single service account in your project: either the one you pass as `customer_service_account_email`, or one the module creates (`clumio-protect-sa-<token prefix>`). These two grants are the impersonation boundary. Clumio holds no grant on any other service account in your project.
- Clumio acts in your project by impersonating that customer service account. The module creates no service account keys.
- Cloud Audit Logs record impersonated calls under the customer service account, with the Clumio service account named in the delegation info. Admin Activity logs are always on. Data Access logs, which record object reads, are off by default for Cloud Storage; enable them if you need a record of every read.
- Separately from impersonation, the Clumio service account holds `roles/pubsub.subscriber` on the Clumio delta topic only, so it can attach its change-feed subscription.

Set `manage_service_account_impersonation = false` to provision the impersonation grants with your own tooling instead.

### What Clumio can do in your project

When `is_gcs_enabled` and `manage_gcs_iam` are both true, the customer service account receives three project-level custom roles. **They are bound at the project, not per bucket, so they apply to every bucket in the project, including buckets created later.**

| Role | Lets Clumio |
|------|-------------|
| `ClumioGCSInventoryPermissions` | List and read metadata of every bucket; read Cloud Monitoring time series project-wide |
| `ClumioGCSBackupPermissions` | Read every object in every bucket; create buckets and update bucket configuration (including lifecycle and notification settings); manage Storage Transfer Service jobs and Storage Insights inventory reports; read Cloud Monitoring time series project-wide |
| `ClumioGCSRestorePermissions` | Create, overwrite, and delete objects in every bucket |

None of the roles grants `storage.buckets.delete`, permission to read or change project or bucket IAM policy, or access to any service other than Cloud Storage, Storage Transfer Service, Storage Insights, and Cloud Monitoring.

The module also grants Google-managed service agents the access the inventory pipeline needs: project-level `roles/storage.insightsCollectorService` (Storage Insights), `roles/storagetransfer.serviceAgent` (Storage Transfer), and `roles/pubsub.publisher` (Cloud Storage), plus grants scoped to the inventory bridge buckets and the delta topic. These identities are operated by Google, not by Clumio.

To scope Clumio's data access more narrowly than the whole project, set `manage_gcs_iam = false` and bind equivalent permissions yourself, for example on individual buckets. Clumio can then protect only the buckets those bindings cover.

### Shared responsibility

| Clumio is responsible for | You are responsible for |
|---------------------------|-------------------------|
| Protecting the Clumio service account and the credentials it uses | Who in your organization can apply, change, or destroy this module, and who can impersonate the customer service account |
| Using the granted access only to inventory, back up, and restore the data you protect | Protecting your Terraform state, which records the Clumio token and the identities above |
| | Enabling Data Access audit logs and monitoring the customer service account's activity |
| | Creating, rotating, and controlling access to any CMEK keys you supply |
| | Revoking access and removing leftover resources when you offboard (see below) |

### Encryption

- By default, the resources this module creates use Google-managed encryption.
- **Inventory bridge buckets:** set `inventory_bridge_kms_key_name` on a `region_configuration` entry to encrypt a template-created bucket with your own Cloud KMS key (CMEK). The module grants the Cloud Storage, Storage Insights, and Storage Transfer service agents `roles/cloudkms.cryptoKeyEncrypterDecrypter` on that key. For a bucket you supply through `using_custom_inventory_bridge_bucket`, you manage its CMEK and key access yourself.
- **Delta topic:** set `delta_topic_kms_key_name` to encrypt the Pub/Sub delta topic with CMEK. The module grants the Pub/Sub service agent access to the key.
- **Your source buckets:** the module does not change their encryption. Buckets you already encrypt with CMEK stay encrypted with your key.
- The Clumio service account and the customer service account are never granted access to your keys.

### Revoking access

To cut off Clumio immediately, without destroying anything, remove the impersonation grants from the customer service account:

```sh
gcloud iam service-accounts remove-iam-policy-binding CUSTOMER_SA_EMAIL \
  --member="serviceAccount:CLUMIO_SA_EMAIL" --role="roles/iam.serviceAccountTokenCreator"
gcloud iam service-accounts remove-iam-policy-binding CUSTOMER_SA_EMAIL \
  --member="serviceAccount:CLUMIO_SA_EMAIL" --role="roles/iam.serviceAccountUser"
```

Disabling the customer service account (`gcloud iam service-accounts disable CUSTOMER_SA_EMAIL`) has the same effect. The next `terraform apply` restores both grants, so follow up with a full offboarding or set `manage_service_account_impersonation = false`.

### Offboarding

Run `terraform destroy` to remove everything this module created. Empty every template-created inventory bridge bucket first; the module never force-deletes a bucket, so destroy fails while one still holds objects.

`terraform destroy` removes the created service account, the impersonation grants, the custom roles and their bindings, the delta topic and Cloud Asset feed, the template-created inventory bridge buckets, and every IAM grant the module made, including the service-agent and CMEK key grants. It does **not** return the project to its exact prior state. The following remain:

- **Enabled APIs.** The module enables `storage`, `storagetransfer`, `pubsub`, `cloudasset`, `storageinsights`, and `monitoring`, plus `cloudkms` when a CMEK key is configured, all with `disable_on_destroy = false`. They stay enabled because other workloads in your project may depend on them, and disabling an API that other enabled services depend on fails. Disable any you do not need with `gcloud services disable SERVICE.googleapis.com --project=PROJECT_ID`.
- **Google-managed service agents.** The Cloud Asset, Storage Insights, Pub/Sub, Cloud Storage, and Storage Transfer service agents continue to exist. Google creates and owns them, and they cannot be deleted. The grants this module gave them are removed.
- **A customer service account you supplied.** The module removes only the grants it added to it.
- **Resources Clumio created at run time.** The custom roles let Clumio create Storage Transfer Service jobs and Storage Insights inventory report configurations, and update bucket configuration. These are not Terraform resources, so `terraform destroy` does not remove them. Check for and delete any that remain.
- **Custom role IDs.** GCP keeps deleted custom roles in a soft-deleted state for a period before purging them, so the same role IDs cannot be recreated right away.
