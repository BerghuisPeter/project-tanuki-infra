output "auth_service_url" {
  value = module.auth_service.service_url
}

output "profile_service_url" {
  value = module.profile_service.service_url
}

output "angular_frontend_url" {
  value = module.angular_frontend.service_url
}

output "socket_server_url" {
  value = module.socket_server.service_url
}
