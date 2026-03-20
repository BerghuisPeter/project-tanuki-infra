# Service account for Cloud Run services to assume at runtime
resource "google_service_account" "cloudrun_runtime" {
  account_id   = "tanuki-cloudrun-runtime"
  display_name = "Tanuki Cloud Run Runtime"
}

# Grant the runtime service account minimal required roles
resource "google_project_iam_member" "runtime_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_runtime.email}"
}

resource "google_project_iam_member" "runtime_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_runtime.email}"
}

resource "google_project_iam_member" "runtime_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_runtime.email}"
}

# The Terraform Management Service Account is usually created once manually 
# to 'bootstrap' the project, but we can also define it here to manage its 
# permissions and ensure it exists.

resource "google_service_account" "terraform_mgmt" {
  account_id   = "terraform-mgmt"
  display_name = "Terraform Management"
}

# Roles for the Terraform Management Service Account to manage the project
# Note: You need to apply these once with a user account that has 'Project Owner' 
# or 'IAM Security Admin' permissions.

locals {
  terraform_mgmt_roles = [
    "roles/run.admin",
    "roles/artifactregistry.repoAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.securityAdmin",
    "roles/storage.admin",
    "roles/secretmanager.admin"
  ]
}

resource "google_project_iam_member" "terraform_mgmt_roles" {
  for_each = toset(local.terraform_mgmt_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform_mgmt.email}"
}

# Service account for Application (Back-end) CI/CD
# This account is used by the application repositories to build/push images 
# and potentially trigger a Cloud Run revision update.
resource "google_service_account" "app_cicd" {
  account_id   = "tanuki-app-cicd"
  display_name = "Tanuki Application CI/CD"
}

# Roles for the App CI/CD Service Account
# 1. Allow it to push images to Artifact Registry
resource "google_project_iam_member" "app_cicd_gar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.app_cicd.email}"
}

# 2. Allow it to create new Cloud Run revisions (with NO config changes)
resource "google_project_iam_member" "app_cicd_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.app_cicd.email}"
}

# 3. Allow it to use the runtime service account when creating revisions
resource "google_service_account_iam_member" "app_cicd_act_as" {
  service_account_id = google_service_account.cloudrun_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.app_cicd.email}"
}
