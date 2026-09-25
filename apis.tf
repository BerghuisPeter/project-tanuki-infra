locals {
  maps_apis = [
    "geocoding-backend.googleapis.com",
    "places.googleapis.com",
  ]
}

resource "google_project_service" "maps_services" {
  for_each                   = toset(local.maps_apis)
  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}