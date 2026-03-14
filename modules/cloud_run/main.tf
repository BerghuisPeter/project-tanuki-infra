variable "service_name" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "env_vars" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "service_account" {
  description = "The service account to run the Cloud Run service as"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name to map to this service (optional)"
  type        = string
  default     = null
}

resource "google_cloud_run_v2_service" "default" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account
    containers {
      image = var.image

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }
}

# Allow public access to the service
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.default.name
  location = google_cloud_run_v2_service.default.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Domain mapping (optional)
resource "google_cloud_run_domain_mapping" "default" {
  count    = var.domain_name != null ? 1 : 0
  location = var.region
  name     = var.domain_name

  metadata {
    namespace = google_cloud_run_v2_service.default.project
  }

  spec {
    route_name = google_cloud_run_v2_service.default.name
  }
}

output "service_url" {
  value = google_cloud_run_v2_service.default.uri
}

output "domain_mapping_status" {
  value = length(google_cloud_run_domain_mapping.default) > 0 ? google_cloud_run_domain_mapping.default[0].status : null
}
