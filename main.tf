# Common environment variables
locals {
  # Dynamically construct the CORS allowed origins
  # We include the custom frontend domains if provided, AND the GRC generated URL.
  # We also include any additional origins from var.app_cors_allowed_origins.
  all_cors_origins = split(";", var.app_cors_allowed_origins)

  # Join the origins with a semicolon (;) as requested
  dynamic_cors_list = join(";", distinct(local.all_cors_origins))

  common_back_env = [
    { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
    { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
    { name = "JWT_EXPIRATION", value = var.jwt_expiration },
    { name = "JWT_REFRESH_EXPIRATION", value = var.jwt_refresh_expiration },
    { name = "APP_CORS_ALLOWED_ORIGINS", value = local.dynamic_cors_list },
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
  service_name    = "${var.angular_image_name}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.angular_gar_repo}/${var.angular_image_name}:latest"
  service_account = var.cloud_run_service_account
  domain_name     = replace(var.front_url, "https://", "")
  env_vars = [
    { name = "NGINX_ENVSUBST_OUTPUT_DIR", value = "/etc/nginx" },
    { name = "AUTH_API_URL", value = var.auth_domain != null && var.auth_domain != "" ? "https://${var.auth_domain}" : module.auth_service.service_url },
    { name = "PROFILE_API_URL", value = var.profile_domain != null && var.profile_domain != "" ? "https://${var.profile_domain}" : module.profile_service.service_url },
    { name = "SOCKET_URL", value = var.socket_domain != null && var.socket_domain != "" ? "https://${var.socket_domain}" : module.socket_server.service_url },
  ]
}

module "socket_server" {
  source          = "./modules/cloud_run"
  service_name    = "${var.socket_image_name}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.socket_gar_repo}/${var.socket_image_name}:latest"
  service_account = var.cloud_run_service_account
  domain_name     = var.socket_domain
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
  service_account = var.cloud_run_service_account
  domain_name     = var.auth_domain
  env_vars        = concat(local.common_back_env, [
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
  service_account = var.cloud_run_service_account
  domain_name     = var.profile_domain
  env_vars        = local.common_back_env
  secret_env_vars = local.common_secret_env
}
