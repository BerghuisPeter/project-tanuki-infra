# Tanuki Infrastructure (Terraform)

This directory contains the Terraform configuration to deploy the Tanuki backend services to Google Cloud Platform.

## Architecture

- **Google Cloud Run (V2)**: Hosts `auth-service` and `profile-service`.
- **Environment Variables**: Stores configuration and secrets (passed from Terraform/CI-CD).
- **CockroachDB Serverless**: External database.
- **Google Artifact Registry**: Where Docker images are stored.

## Project Structure

```text
terraform-infra/
├── main.tf               # Main orchestration
├── variables.tf          # Global variables
├── providers.tf          # GCP provider & backend config
├── outputs.tf            # Service URLs
├── terraform.tfvars.example # Template for your tfvars
├── environments/         # Environment-specific variables
│   ├── dev.tfvars        # Values for development
│   └── prod.tfvars       # Values for production
└── modules/
    └── cloud_run/        # Module to create Cloud Run services
```

## Local Development vs. Cloud Infrastructure

- **Local Development**: Use **Docker Compose** (`compose.yaml` in the root). Terraform is not intended for your local machine's runtime.
- **Cloud Infrastructure (Dev/Prod)**: Use **Terraform** to provision and manage resources in Google Cloud.

The `environments/` directory only contains variables for cloud environments. You do not need a `local.tfvars`.

## Deployment Guide: The "Foundation → Images → Services" Sequence

To deploy this project to a brand-new Google Cloud project, you must follow this specific sequence. This addresses the external dependencies (like your Docker images) and the "Chicken-and-Egg" problem with service account identities.

### 1. The Bootstrap (Day 0)
Initially, you must run Terraform using your own identity (your Google account) which has **Project Owner** permissions.

**Command:**
```bash
terraform apply \
  -target="google_service_account.terraform_mgmt" \
  -target="google_project_iam_member.terraform_mgmt_roles" \
  -var-file="environments/dev.tfvars"
```

*   **Reasoning**: Terraform needs a "Management" identity (`terraform-mgmt`) to manage the project. However, it cannot use that identity to create itself. You use your personal account once to "spawn" the automation identity.

---

### 2. Create the Artifact Registry Repositories
Once the service account exists, create the "buckets" where your Docker images will live.

**Command:**
```bash
terraform apply \
  -target="google_artifact_registry_repository.tanuki_back_repo" \
  -target="google_artifact_registry_repository.angular_repo" \
  -target="google_artifact_registry_repository.socket_repo" \
  -var-file="environments/dev.tfvars"
```

*   **Reasoning**: Your CI/CD pipeline (GitHub Actions) cannot push a Docker image to a repository that doesn't exist yet. You must create the repositories before you can push images.

---

### 3. Push Docker Images (User Action)
Use your CI/CD pipeline or local Docker to build and push at least one image for each service (Auth, Profile, Angular, and Socket) to the new repositories.

#### Choosing Your Strategy
Depending on your project's maturity, choose one of these common strategies:

1.  **The Bootstrap & CI/CD** (Recommended): Provision the foundations with Terraform, then run your CI/CD pipeline (e.g., GitHub Actions) to build/push the real application code. Finally, run Terraform again for full deployment.
2.  **The Placeholder (Nginx)**: Pull a tiny public image like `nginx:alpine`, tag it for your GAR repositories, and push it. This allows you to finish the infrastructure setup and verify networking before the real app code is ready.
3.  **The Golden Image**: Use a pre-built, secure "base" image maintained by your organization.

<details>
<summary><b>Example: Using a Placeholder (Nginx)</b></summary>

```bash
# Set your variables
REGION="asia-northeast1"
PROJECT="tanuki-dev"
BACK_REPO="tanuki-back-repo"

# Pull, Tag, and Push (Example for Auth Service)
docker pull nginx:alpine
docker tag nginx:alpine ${REGION}-docker.pkg.dev/${PROJECT}/${BACK_REPO}/auth-service:latest
docker push ${REGION}-docker.pkg.dev/${PROJECT}/${BACK_REPO}/auth-service:latest
```
</details>

<details>
<summary><b>Pro-Tip: Migrating Images from another GCP Project (Bash)</b></summary>

If you have existing images in another Google Cloud project, you can "copy" them directly to your new registry without downloading/uploading from your machine.

1. **Authenticate for both projects**:
   ```bash
   gcloud auth configure-docker asia-northeast1-docker.pkg.dev
   ```

2. **Run the direct copy command**:
   ```bash
   # Variables for your migration
   OLD_PROJECT="old-project-id"
   OLD_REPO="old-repo-name"
   REGION="asia-northeast1"
   NEW_PROJECT="tanuki-dev"

   # Example: Auth Service
   gcloud container images add-tag \
     "${REGION}-docker.pkg.dev/${OLD_PROJECT}/${OLD_REPO}/auth-service:latest" \
     "${REGION}-docker.pkg.dev/${NEW_PROJECT}/tanuki-back-repo/auth-service:latest"

   # Example: Angular Frontend
   gcloud container images add-tag \
     "${REGION}-docker.pkg.dev/${OLD_PROJECT}/${OLD_REPO}/tanuki-angular:dev" \
     "${REGION}-docker.pkg.dev/${NEW_PROJECT}/tanuki-angular-repo/tanuki-angular:dev"
   ```

*Why use this?* It happens entirely within Google's network, saving bandwidth and time.
</details>

*   **Reasoning**: **Cloud Run will fail to deploy if the Docker image does not exist.** Terraform is the "manager" that points Cloud Run to the image, but it cannot create the application code itself.

---

### 4. Full Infrastructure Deployment
Once the images are in the registry, you can run a complete apply. This will deploy the four Cloud Run services and link them to the `tanuki-cloudrun-runtime` service account.

**Command:**
```bash
terraform apply -var-file="environments/dev.tfvars"
```

*   **Reasoning**: Now that all foundations (APIs, Identity, and Images) are in place, Terraform can safely orchestrate the deployment of all services and their IAM permissions in one go.

---

## Getting Started (Infrastructure Setup)

These steps are only required when you need to **initially provision** the cloud infrastructure or **manually update** it. For daily application development, stick to **Docker Compose**.

1.  **Install Terraform**: [Download link](https://developer.hashicorp.com/terraform/downloads). Ensure the executable is in your system's `PATH`.
    -   *Note*: If installed manually (e.g., at `C:\DEV\terraform`), you must add that directory to your environment variables.
2.  **Authenticate GCP**:
    ```bash
    gcloud auth application-default login
    ```
3.  **Create the Remote State Bucket (One-Time Setup)**:
    Before using a remote backend, you must manually create the GCS bucket. Terraform cannot create the bucket it uses to store its own state.
    ```bash
    # Replace 'my-unique-tanuki-state-bucket' with a globally unique name
    gcloud storage buckets create gs://my-unique-tanuki-state-bucket --location=europe-west1
    ```
4.  **Prepare Variables**:
    - Choose an environment (e.g., `dev`).
    - Edit `environments/dev.tfvars` with your actual values (Project ID, DB URL, etc.).
5.  **Enable Remote State (Multi-Environment)**:
    Since each environment (dev/prod) uses a separate GCP project, we use separate backend configuration files to manage state isolation.

    1.  **Create the buckets**: One in each project.
        ```bash
        # For Dev
        gcloud storage buckets create gs://tanuki-dev-tfstate --project=tanuki-dev-123 --location=europe-west1 --public-access-prevention
        # For Prod
        gcloud storage buckets create gs://tanuki-prod-tfstate --project=tanuki-prod-456 --location=europe-west1 --public-access-prevention
        ```
    2.  **Verify Configuration**:
        Check `environments/dev-backend.conf` and `environments/prod-backend.conf`. They should point to your newly created buckets.
        ```hcl
        bucket = "tanuki-dev-tfstate"
        prefix = "terraform/state"
        ```
    3.  **Ensure `providers.tf` is empty**:
        The `backend "gcs" {}` block in `providers.tf` must remain empty to allow dynamic configuration.

6.  **Initialize (Environment-Specific)**:
    When switching between environments, you must re-initialize with the correct backend configuration.
    ```bash
    # For Dev
    terraform init -backend-config="environments/dev-backend.conf" -reconfigure

    # For Prod
    terraform init -backend-config="environments/prod-backend.conf" -reconfigure
    ```
    The `-reconfigure` flag is crucial when switching between projects to prevent Terraform from trying to copy state between them.

7.  **Provision (Specific Environment)**:
    - **Plan**: `terraform plan -var-file="environments/dev.tfvars"`
    - **Apply**: `terraform apply -var-file="environments/dev.tfvars"`

## Managing Multiple Environments

To differentiate between `dev` and `prod`, you use separate `.tfvars` files located in the `environments/` directory.

### Local Development
When running Terraform locally, always specify the variable file for the environment you are working on:
- **Dev**: `terraform plan -var-file="environments/dev.tfvars"`
- **Prod**: `terraform plan -var-file="environments/prod.tfvars"`

### CI/CD (GitHub Actions)
In an enterprise setup, you don't store secrets in `.tfvars` files. Instead:
1.  Store your secrets in **GitHub Actions Secrets**.
2.  Pass them to Terraform using environment variables prefixed with `TF_VAR_`.

Example step in GitHub Actions:
```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve -var-file="environments/${{ inputs.environment }}.tfvars"
  env:
    TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
    TF_VAR_jwt_secret: ${{ secrets.JWT_SECRET }}
    # Terraform automatically maps TF_VAR_name to the variable "name"
```

## Cost-Effective Configuration

This setup is optimized for cost by avoiding paid services like **Google Secret Manager**. Instead:
1.  Secrets are defined as `sensitive` variables in Terraform.
2.  They are passed as standard environment variables to Google Cloud Run.
3.  In production, you should store these secrets in **GitHub Actions Secrets** and pass them to Terraform during deployment.

## Enterprise Best Practices Applied

1.  **Modularity**: Services are managed via reusable modules.
2.  **IAM Security**: Cloud Run services are configured with public invoker roles.
3.  **Declarative Infrastructure**: Your entire backend stack is defined as code.

## Next Steps

- **CI/CD Integration**: Update your GitHub Actions to run `terraform plan` on PRs and `terraform apply` on merges.
