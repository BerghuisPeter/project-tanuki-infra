variable "job_name" {
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

variable "secret_env_vars" {
  type = list(object({
    name    = string
    secret  = string
    version = string
  }))
  default = []
}

variable "service_account" {
  description = "The service account to run the Cloud Run job as"
  type        = string
  default     = null
}

resource "google_cloud_run_v2_job" "default" {
  name     = var.job_name
  location = var.region

  template {
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

        dynamic "env" {
          for_each = var.secret_env_vars
          content {
            name = env.value.name
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}

output "job_name" {
  value = google_cloud_run_v2_job.default.name
}
