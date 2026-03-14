# Common environment variables
locals {
  # Dynamically construct the CORS allowed origins
  # We include the custom frontend domains if provided, AND the GRC generated URL.
  # We also include any additional origins from var.app_cors_allowed_origins.
  all_cors_origins = compact(distinct(concat(
    split(";", var.app_cors_allowed_origins),
    [
      var.frontend_url
    ]
  )))

  # Join the origins with a semicolon (;) as requested
  dynamic_cors_list = join(";", distinct(local.all_cors_origins))

  common_env = [
    { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
    { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
    { name = "JWT_EXPIRATION", value = var.jwt_expiration },
    { name = "JWT_REFRESH_EXPIRATION", value = var.jwt_refresh_expiration },
    { name = "GOOGLE_REDIRECT_URI", value = var.google_redirect_uri },
    { name = "FRONTEND_URL", value = var.frontend_url },
    { name = "APP_CORS_ALLOWED_ORIGINS", value = local.dynamic_cors_list },
    # Sensitive variables passed as standard env vars to avoid Secret Manager costs
    { name = "SPRING_DATASOURCE_URL", value = var.db_url },
    { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password },
    { name = "JWT_SECRET", value = var.jwt_secret },
    { name = "GOOGLE_CLIENT_SECRET", value = var.google_client_secret }
  ]
}

module "angular_frontend" {
  source          = "./modules/cloud_run"
  service_name    = "${var.angular_image_name}-${var.environment}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.angular_gar_repo}/${var.angular_image_name}:${var.environment}"
  service_account = var.cloud_run_service_account
  domain_name     = var.google_redirect_uri
  env_vars = [
    { name = "NGINX_ENVSUBST_OUTPUT_DIR", value = "/etc/nginx" },
    { name = "AUTH_API_URL", value = var.auth_domain != null && var.auth_domain != "" ? "https://${var.auth_domain}" : module.auth_service.service_url },
    { name = "PROFILE_API_URL", value = var.profile_domain != null && var.profile_domain != "" ? "https://${var.profile_domain}" : module.profile_service.service_url },
    { name = "SOCKET_URL", value = var.socket_domain != null && var.socket_domain != "" ? "https://${var.socket_domain}" : module.socket_server.service_url },
  ]
}

module "socket_server" {
  source          = "./modules/cloud_run"
  service_name    = "${var.socket_image_name}-${var.environment}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.socket_gar_repo}/${var.socket_image_name}:${var.environment}"
  service_account = var.cloud_run_service_account
  domain_name     = var.socket_domain
  env_vars = [
    { name = "NODE_ENV", value = var.environment == "dev" ? "development" : "production" },
    { name = "CORS_DOMAIN", value = local.dynamic_cors_list }
  ]
}

module "auth_service" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-back-auth-service-${var.environment}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/auth-service:latest"
  service_account = var.cloud_run_service_account
  domain_name     = var.auth_domain
  env_vars        = local.common_env
}

module "profile_service" {
  source          = "./modules/cloud_run"
  service_name    = "tanuki-back-profile-service-${var.environment}"
  region          = var.region
  image           = "${var.gar_location}-docker.pkg.dev/${var.project_id}/${var.gar_repository}/profile-service:latest"
  service_account = var.cloud_run_service_account
  domain_name     = var.profile_domain
  env_vars        = local.common_env
}
