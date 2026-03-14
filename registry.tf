resource "google_artifact_registry_repository" "tanuki_back_repo" {
  location      = var.gar_location
  repository_id = var.gar_repository
  description   = "Docker repository for Tanuki backend services (Auth, Profile, etc.)"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "angular_repo" {
  location      = var.gar_location
  repository_id = var.angular_gar_repo
  description   = "Docker repository for Angular frontend"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "socket_repo" {
  location      = var.gar_location
  repository_id = var.socket_gar_repo
  description   = "Docker repository for Socket server"
  format        = "DOCKER"
}
