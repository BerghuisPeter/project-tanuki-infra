# AGENTS.md — Tanuki Infrastructure Guide for AI Agents

This document provides system context, architectural blueprints, operational guardrails, and execution workflows for AI agents managing the Tanuki Terraform infrastructure.

---

## 1. Project Overview & Architecture

This repository manages Google Cloud Platform (GCP) resources for the Tanuki microservices ecosystem using Terraform `>= 1.5.0` with the `hashicorp/google` provider `~> 5.0`.

### Core Managed Infrastructure
- **Compute (Cloud Run v2 Services)**:
  - `angular_frontend`: Web UI running on Nginx (`tanuki-angular`).
  - `socket_server`: WebSocket real-time service (`tanuki-socket`).
  - `auth_service`: Spring Boot Authentication & OAuth2 service (`tanuki-back-auth-service`).
  - `profile_service`: Spring Boot User profile & storage service (`tanuki-back-profile-service`).
  - `goshuin_service`: Spring Boot Temple stamp tracking service (`tanuki-back-goshuin-service`).
  - `tile_server`: Map tiles rendering service (`tanuki-tile-server`).
- **Compute (Cloud Run v2 Jobs)**:
  - `liquibase_migration`: Database migration runner executed per environment.
- **Artifact Registry (GAR)**:
  - Docker repositories: `tanuki-back-repo`, `tanuki-angular-repo`, `tanuki-socket-repo`.
  - Automated 7-day retention cleanup policies preserving `:latest` tags.
- **Storage (GCS)**:
  - `tanuki-{env}-assets`: Public assets bucket with CORS and `force_destroy` enabled on `dev` only.
  - Remote state backend buckets: `tanuki-{env}-tfstate`.
- **Identity & Access Management (IAM)**:
  - `tanuki-cloudrun-runtime`: Runtime service account assumed by all Cloud Run services.
  - `terraform-mgmt`: Automation service account for Terraform provisioning.
- **Networking & DNS (Cloud DNS)**:
  - Zone: `project-tanuki-zone` (`project-tanuki.net.`), exclusively hosted in the `prod` project (`tanuki-prod-489811`).
  - Cross-project DNS references: `dev` subdomains point to `ghs.googlehosted.com.`.
- **Secret Management**:
  - Integration with GCP Secret Manager (`db_url`, `db_password`, `jwt_secret`, `google_client_secret`, `GCP_STORAGE_CREDENTIALS_JSON`).

---

## 2. Directory Structure & File Map

```text
project-tanuki-infra/
├── AGENTS.md                          # AI agent operating manual & repository context (this file)
├── README.md                          # Human bootstrap and deployment documentation
├── main.tf                            # Primary orchestration: Cloud Run services, jobs & locals
├── variables.tf                       # Variable definitions and validation types
├── providers.tf                       # Terraform block, GCS backend declaration, Google provider
├── outputs.tf                         # Exported attributes (e.g. service URLs, nameservers)
├── iam.tf                             # Service accounts and IAM role bindings
├── dns.tf                             # Cloud DNS zone, A/AAAA records, CNAME subdomains
├── registry.tf                        # Artifact Registry repositories & lifecycle policies
├── storage.tf                         # Cloud Storage buckets, CORS configuration, bucket IAM
├── environments/
│   ├── dev-backend.conf              # GCS backend configuration for dev state
│   ├── dev.tfvars                    # Input variables for development environment
│   ├── prod-backend.conf             # GCS backend configuration for prod state
│   └── prod.tfvars                   # Input variables for production environment
├── modules/
│   ├── cloud_run/                    # Reusable module for Cloud Run v2 services & domain mappings
│   │   └── main.tf
│   └── cloud_run_job/                # Reusable module for Cloud Run v2 migration jobs
│       └── main.tf
└── .github/workflows/
    ├── terraform.yml                  # PR plan checks + Master branch auto-apply
    └── cleanup-revisions.yml          # Monthly cron cleanup of inactive Cloud Run revisions
```

---

## 3. Environment Topologies

| Property | Development (`dev`) | Production (`prod`) |
| :--- | :--- | :--- |
| **GCP Project ID** | `tanuki-dev` | `tanuki-prod-489811` |
| **Default Region** | `asia-northeast1` | `asia-northeast1` |
| **State Bucket** | `tanuki-dev-tfstate` | `tanuki-prod-tfstate` |
| **State Prefix** | `terraform/state` | `terraform/state` |
| **DNS Management** | Referenced via `data.google_dns_managed_zone` | Created via `google_dns_managed_zone` |
| **Base Domain** | `dev.project-tanuki.net` | `project-tanuki.net` |
| **Subdomain Pattern** | `dev.<service>.project-tanuki.net` | `<service>.project-tanuki.net` |
| **Bucket Force Destroy** | `true` | `false` |

---

## 4. Standard Operational Commands

When executing Terraform commands, always isolate environment state and supply the appropriate variable files.

### 4.1. Environment Switching & Initialization
```bash
# Initialize dev backend
terraform init -backend-config="environments/dev-backend.conf" -reconfigure

# Initialize prod backend
terraform init -backend-config="environments/prod-backend.conf" -reconfigure
```
*Note: Always include `-reconfigure` when alternating between environments to prevent state corruption.*

### 4.2. Code Quality & Static Validation
```bash
# Format check
terraform fmt -check -diff

# Auto-format all files
terraform fmt -recursive

# Syntax and type validation
terraform validate
```

### 4.3. Planning Changes
```bash
# Dev plan
terraform plan -var-file="environments/dev.tfvars"

# Prod plan
terraform plan -var-file="environments/prod.tfvars"

# Save binary plan for deterministic execution
terraform plan -var-file="environments/dev.tfvars" -out="dev.tfplan"
```

### 4.4. Applying Changes
```bash
# Targeted bootstrap apply
terraform apply -var-file="environments/dev.tfvars" -target="google_service_account.terraform_mgmt"

# Full environment apply
terraform apply -var-file="environments/dev.tfvars"
```

---

## 5. Security & Sensitive Data Guidelines

1. **Zero Secret Exposure**:
   - Never commit passwords, tokens, private keys, or credentials in `.tf` or `.tfvars` files.
   - Database passwords, JWT keys, and OAuth client secrets are injected via GCP Secret Manager into Cloud Run containers at runtime.
2. **State Security**:
   - Do not commit `.tfstate`, `.tfstate.backup`, or `*.tfplan` files to version control.
   - Remote state storage uses encrypted GCS buckets with uniform bucket-level access.
3. **Least Privilege IAM**:
   - Runtime service account (`tanuki-cloudrun-runtime`) must only have permissions required for execution: logging, metric writing, Secret Manager access, and object storage access.
   - Management service account (`terraform-mgmt`) holds administrative roles strictly for provisioning declared infrastructure.

---

## 6. Modification Patterns & Best Practices

### 6.1. Adding a New Cloud Run Microservice
To add a new service (e.g., `notification_service`):
1. **Define Subdomain in `main.tf`**:
   Add to `locals`:
   ```hcl
   notification_domain = "${local.service_domain_suffix}notification.${local.base_domain}"
   ```
2. **Instantiate Cloud Run Module in `main.tf`**:
   ```hcl
   module "notification_service" {
     source          = "./modules/cloud_run"
     service_name    = "tanuki-back-notification-service"
     region          = var.region
     image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/notification-service:latest"
     service_account = google_service_account.cloudrun_runtime.email
     domain_name     = local.notification_domain
     env_vars        = local.common_back_env
     secret_env_vars = local.common_secret_env
   }
   ```
3. **Register DNS Records in `dns.tf`**:
   - Add subdomain mapping to `local.dev_service_subdomains` and `local.service_subdomains`.
4. **Update CORS Configuration**:
   - Ensure the new subdomain is added to `app_cors_allowed_origins` in `environments/dev.tfvars` and `environments/prod.tfvars`.
5. **Update Frontend Gateway URLs**:
   - Add environment injection in `module.angular_frontend.env_vars`.

### 6.2. Adding a New Secret
1. Create or ensure the secret exists in GCP Secret Manager (e.g., `new_api_key`).
2. Add reference in `locals.common_secret_env` in `main.tf`:
   ```hcl
   { name = "NEW_API_KEY", secret = "new_api_key", version = "latest" }
   ```
3. Verify IAM permissions in `iam.tf` ensure `roles/secretmanager.secretAccessor` is bound to `google_service_account.cloudrun_runtime`.

---

## 7. CI/CD & Automation Pipelines

- **Pull Requests**:
  - GitHub Actions runs `terraform fmt -check`, `terraform init`, and `terraform plan` against `prod`.
  - Outputs plan diff directly as a PR comment using `actions/github-script`.
- **Master Branch Push**:
  - Automatically executes `terraform apply -auto-approve -var-file="environments/prod.tfvars"`.
- **Monthly Maintenance**:
  - `cleanup-revisions.yml` runs on the 1st of every month to purge inactive Cloud Run revisions older than 30 days.

---

## 8. Agent Troubleshooting & Edge Cases

| Issue | Root Cause | Remediation |
| :--- | :--- | :--- |
| **Backend State Lock** | Previous interrupted run left state locked in GCS | Run `terraform force-unlock <LOCK_ID>` after verifying no other agent is applying. |
| **DNS Zone Not Found in Dev** | `dns.tf` references prod zone `tanuki-prod-489811` | Ensure Terraform runner has cross-project DNS read permissions or prod DNS zone exists. |
| **Domain Mapping Verification Error** | Domain ownership not proven in Google Search Console | Management SA must be added as Verified Owner in Google Webmaster Central prior to apply. |
| **Container Image Pull Failure** | Service deployed before image pushed to GAR | Use bootstrap sequence: create Artifact Registry first, push image/placeholder, then deploy service. |
| **Secret Version Not Found** | Secret declared in `secret_env_vars` does not exist in Secret Manager | Create secret in GCP Secret Manager before deploying the container revision. |
