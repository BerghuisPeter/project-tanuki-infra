variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "gar_location" {
  description = "Google Artifact Registry location"
  type        = string
  default     = "asia-northeast1"
}

variable "gar_repository" {
  description = "Google Artifact Registry repository name"
  type        = string
}

# CockroachDB Configuration
# DEPRECATED: Values moved to Secret Manager (secret_id: db_url)
variable "db_url" {
  description = "CockroachDB connection URL"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_username" {
  description = "CockroachDB username"
  type        = string
}

# DEPRECATED: Values moved to Secret Manager (secret_id: db_password)
variable "db_password" {
  description = "CockroachDB password"
  type        = string
  sensitive   = true
  default     = ""
}

# Security variables
# DEPRECATED: Values moved to Secret Manager (secret_id: jwt_secret)
variable "jwt_secret" {
  description = "JWT Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_expiration" {
  description = "JWT expiration time"
  type        = string
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token expiration time"
  type        = string
}

variable "google_client_id" {
  description = "Google OAuth2 client ID"
  type        = string
}

# DEPRECATED: Values moved to Secret Manager (secret_id: google_client_secret)
variable "google_client_secret" {
  description = "Google OAuth2 client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_redirect_uri" {
  description = "Google OAuth2 redirect URI"
  type        = string
}

variable "app_cors_allowed_origins" {
  description = "Additional CORS allowed origins (semicolon separated)"
  type        = string
  default     = ""
}

variable "angular_gar_repo" {
  description = "Google Artifact Registry repository for Angular"
  type        = string
}

variable "angular_image_name" {
  description = "Image name for Angular"
  type        = string
}

variable "socket_gar_repo" {
  description = "Google Artifact Registry repository for Socket service"
  type        = string
}

variable "socket_image_name" {
  description = "Image name for Socket service"
  type        = string
}

variable "socket_domain" {
  description = "Domain name for Socket service"
  type        = string
  default     = null
}

variable "auth_domain" {
  description = "Domain name for Auth service"
  type        = string
  default     = null
}

variable "profile_domain" {
  description = "Domain name for Profile service"
  type        = string
  default     = null
}


variable "front_url" {
  description = "url for the tanuki front-end"
  type        = string
}