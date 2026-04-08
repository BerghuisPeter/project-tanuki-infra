locals {
  # The DNS zone is managed only in the production project.
  # We identify the production project by its ID.
  dns_project_id = "tanuki-prod-489811"
  is_prod        = var.environment == "prod"
}

# -----------------------------------------------
# Cloud DNS Managed Zone
# -----------------------------------------------
resource "google_dns_managed_zone" "main" {
  name        = "project-tanuki-zone"
  dns_name    = "project-tanuki.net." # trailing dot is required
  description = "Main DNS zone for project-tanuki.net"
  project     = local.dns_project_id

  # Only create the zone if we are in the production environment
  count = local.is_prod ? 1 : 0
}

# Use a data source to reference the zone when we are not in the production project
data "google_dns_managed_zone" "main" {
  name    = "project-tanuki-zone"
  project = local.dns_project_id
}

locals {
  # Helper to get the zone name regardless of whether it was created or referenced
  zone_name = local.is_prod ? google_dns_managed_zone.main[0].name : data.google_dns_managed_zone.main.name
}

# -----------------------------------------------
# Preserve your existing records from Squarespace
# -----------------------------------------------

# Google site verification TXT
resource "google_dns_record_set" "site_verification" {
  count        = local.is_prod ? 1 : 0
  name         = "project-tanuki.net."
  managed_zone = local.zone_name
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["\"google-site-verification=lneFjEz_uaqYkZOJgBAysiSrNXjCFWU1dOgrjIYzR4M\""]
  project      = local.dns_project_id
}

# Root A records (IPv4)
resource "google_dns_record_set" "root_a" {
  count        = local.is_prod ? 1 : 0
  name         = "project-tanuki.net."
  managed_zone = local.zone_name
  type         = "A"
  ttl          = 14400
  rrdatas = [
    "216.239.32.21",
    "216.239.34.21",
    "216.239.36.21",
    "216.239.38.21",
  ]
  project = local.dns_project_id
}

# Root AAAA records (IPv6)
resource "google_dns_record_set" "root_aaaa" {
  count        = local.is_prod ? 1 : 0
  name         = "project-tanuki.net."
  managed_zone = local.zone_name
  type         = "AAAA"
  ttl          = 14400
  rrdatas = [
    "2001:4860:4802:32::15",
    "2001:4860:4802:34::15",
    "2001:4860:4802:36::15",
    "2001:4860:4802:38::15",
  ]
  project = local.dns_project_id
}

# dev CNAME (your existing one)
resource "google_dns_record_set" "dev" {
  count        = local.is_prod ? 1 : 0
  name         = "dev.project-tanuki.net."
  managed_zone = local.zone_name
  type         = "CNAME"
  ttl          = 14400
  rrdatas      = ["ghs.googlehosted.com."]
  project      = local.dns_project_id
}

# -----------------------------------------------
# Subdomains for each Cloud Run service
# -----------------------------------------------

locals {
  # We only include subdomains that are NOT the root domain (Apex).
  # The root domain (project-tanuki.net) cannot have a CNAME and uses the A/AAAA records defined above.
  service_subdomains = {
    for k, v in {
      front   = local.front_domain
      auth    = local.auth_domain
      profile = local.profile_domain
      socket  = local.socket_domain
    } : k => v if v != local.base_domain
  }
}

resource "google_dns_record_set" "services" {
  for_each     = local.service_subdomains
  name         = "${each.value}."
  managed_zone = local.zone_name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["ghs.googlehosted.com."]
  project      = local.dns_project_id
}

# -----------------------------------------------
# Output the nameservers — you'll need these for Squarespace
# -----------------------------------------------
output "nameservers" {
  description = "Set these as your nameservers in Squarespace"
  value       = local.is_prod ? google_dns_managed_zone.main[0].name_servers : data.google_dns_managed_zone.main.name_servers
}