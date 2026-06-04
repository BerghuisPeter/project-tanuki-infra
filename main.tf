# Common environment variables
locals {
  # Dynamically construct the CORS allowed origins
  # We include the custom frontend domains if provided, AND the GRC generated URL.
  # We also include any additional origins from var.app_cors_allowed_origins.
  all_cors_origins = split(";", var.app_cors_allowed_origins)

  # Join the origins with a semicolon (;) as requested
  dynamic_cors_list = join(";", distinct(local.all_cors_origins))

  # Domain Logic
  base_domain = "project-tanuki.net"
  # dev: dev.auth.project-tanuki.net
  # prod: auth.project-tanuki.net
  service_domain_suffix = var.environment == "dev" ? "dev." : ""

  front_domain   = "${local.service_domain_suffix}${local.base_domain}"
  auth_domain    = "${local.service_domain_suffix}auth.${local.base_domain}"
  profile_domain = "${local.service_domain_suffix}profile.${local.base_domain}"
  socket_domain  = "${local.service_domain_suffix}socket.${local.base_domain}"
  goshuin_domain = "${local.service_domain_suffix}goshuin.${local.base_domain}"
  tiles_domain   = "${local.service_domain_suffix}tiles.${local.base_domain}"

  common_back_env = [
    { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
    { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
    { name = "JWT_EXPIRATION", value = var.jwt_expiration },
    { name = "JWT_REFRESH_EXPIRATION", value = var.jwt_refresh_expiration },
    { name = "APP_CORS_ALLOWED_ORIGINS", value = local.dynamic_cors_list },
    { name = "PROFILE_SERVICE_URL", value = local.profile_domain },
    { name = "AUTH_SERVICE_URL", value = local.auth_domain },
    { name = "GOSHUIN_SERVICE_URL", value = local.goshuin_domain },
  ]

  common_secret_env = [
    { name = "SPRING_DATASOURCE_URL", secret = "db_url", version = "latest" },
    { name = "SPRING_DATASOURCE_PASSWORD", secret = "db_password", version = "latest" },
    { name = "JWT_SECRET", secret = "jwt_secret", version = "latest" },
    { name = "GOOGLE_CLIENT_SECRET", secret = "google_client_secret", version = "latest" }
  ]
}

module "angular_frontend" {
  source          = "./modules/cloud_run"
  service_name    = var.angular_image_name
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.angular_gar_repo}/${var.angular_image_name}:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.front_domain
  env_vars = [
    { name = "NGINX_ENVSUBST_OUTPUT_DIR", value = "/etc/nginx" },
    { name = "NG_APP_AUTH_API_URL", value = "https://${local.auth_domain}" },
    { name = "NG_APP_PROFILE_API_URL", value = "https://${local.profile_domain}" },
    { name = "NG_APP_SOCKET_SERVER_URL", value = "https://${local.socket_domain}" },
    { name = "NG_APP_GOSHUIN_API_URL", value = "https://${local.goshuin_domain}" },
    { name = "NG_APP_TILE_SERVER_URL", value = "https://${local.tiles_domain}" },
  ]
}

module "socket_server" {
  source          = "./modules/cloud_run"
  service_name    = var.socket_image_name
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.socket_gar_repo}/${var.socket_image_name}:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.socket_domain
  env_vars = [
    { name = "NODE_ENV", value = var.environment == "dev" ? "development" : "production" },
    { name = "CORS_DOMAIN", value = local.dynamic_cors_list }
  ]
}

module "auth_service" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-back-auth-service"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/auth-service:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.auth_domain
  env_vars = concat(local.common_back_env, [
    { name = "GOOGLE_CLIENT_ID", value = var.google_client_id },
    { name = "GOOGLE_REDIRECT_URI", value = var.google_redirect_uri },
    { name = "FRONT_URL", value = var.front_url }
  ])
  secret_env_vars = local.common_secret_env
}

module "profile_service" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-back-profile-service"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/profile-service:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.profile_domain
  env_vars = concat(local.common_back_env, [
    { name = "GCP_STORAGE_BUCKET_NAME", value = var.app_storage_bucket_name }
  ])
  secret_env_vars = concat(local.common_secret_env, [
    { name = "GCP_STORAGE_CREDENTIALS_JSON", secret = "GCP_STORAGE_CREDENTIALS_JSON", version = "latest" }
  ])
}

module "goshuin_service" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-back-goshuin-service"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/goshuin-service:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.goshuin_domain
  env_vars = concat(local.common_back_env, [
    { name = "GCP_STORAGE_BUCKET_NAME", value = var.app_storage_bucket_name }
  ])
  secret_env_vars = local.common_secret_env
}

module "tile_server" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-tile-server"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/tanuki-tile-server:latest"
  service_account = google_service_account.cloudrun_runtime.email
  domain_name     = local.tiles_domain
}

module "liquibase_migration" {
  source          = "./modules/cloud_run_job"
  job_name        = "liquibase-migration-${var.environment}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/auth-service:latest"
  service_account = google_service_account.cloudrun_runtime.email
  env_vars = [
    { name = "LIQUIBASE_COMMAND_USERNAME", value = var.db_username }
  ]
  secret_env_vars = [
    { name = "LIQUIBASE_COMMAND_URL", secret = "db_url", version = "latest" },
    { name = "LIQUIBASE_COMMAND_PASSWORD", secret = "db_password", version = "latest" }
  ]
}
