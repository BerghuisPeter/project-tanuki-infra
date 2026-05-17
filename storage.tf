resource "google_storage_bucket" "assets" {
  name                        = var.app_storage_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.environment == "dev"

  cors {
    origin = concat(
      var.environment == "dev" ? ["http://localhost:4200"] : [],
      compact(split(";", var.app_cors_allowed_origins))
    )

    method          = ["GET", "PUT", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket_iam_member" "runtime_bucket_admin" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun_runtime.email}"
}
