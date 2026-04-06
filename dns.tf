# -----------------------------------------------
# Cloud DNS Managed Zone
# -----------------------------------------------
resource "google_dns_managed_zone" "main" {
  name        = "project-tanuki-zone"
  dns_name    = "project-tanuki.net." # trailing dot is required
  description = "Main DNS zone for project-tanuki.net"
  project     = var.project_id

  # Ensure IAM roles are applied before creating the DNS zone
  # This avoids 403 errors due to IAM propagation lag.
  depends_on = [google_project_iam_member.terraform_mgmt_roles]
}

# -----------------------------------------------
# Preserve your existing records from Squarespace
# -----------------------------------------------

# Google site verification TXT
resource "google_dns_record_set" "site_verification" {
  name         = "project-tanuki.net."
  managed_zone = google_dns_managed_zone.main.name
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["\"google-site-verification=lneFjEz_uaqYkZOJgBAysiSrNXjCFWU1dOgrjIYzR4M\""]
  project      = var.project_id
}

# Root A records (IPv4)
resource "google_dns_record_set" "root_a" {
  name         = "project-tanuki.net."
  managed_zone = google_dns_managed_zone.main.name
  type         = "A"
  ttl          = 14400
  rrdatas = [
    "216.239.32.21",
    "216.239.34.21",
    "216.239.36.21",
    "216.239.38.21",
  ]
  project = var.project_id
}

# Root AAAA records (IPv6)
resource "google_dns_record_set" "root_aaaa" {
  name         = "project-tanuki.net."
  managed_zone = google_dns_managed_zone.main.name
  type         = "AAAA"
  ttl          = 14400
  rrdatas = [
    "2001:4860:4802:32::15",
    "2001:4860:4802:34::15",
    "2001:4860:4802:36::15",
    "2001:4860:4802:38::15",
  ]
  project = var.project_id
}

# www CNAME
resource "google_dns_record_set" "www" {
  name         = "www.project-tanuki.net."
  managed_zone = google_dns_managed_zone.main.name
  type         = "CNAME"
  ttl          = 14400
  rrdatas      = ["ghs.googlehosted.com."]
  project      = var.project_id
}

# dev CNAME (your existing one)
resource "google_dns_record_set" "dev" {
  name         = "dev.project-tanuki.net."
  managed_zone = google_dns_managed_zone.main.name
  type         = "CNAME"
  ttl          = 14400
  rrdatas      = ["ghs.googlehosted.com."]
  project      = var.project_id
}

# -----------------------------------------------
# Subdomains for each Cloud Run service
# -----------------------------------------------

locals {
  service_subdomains = {
    auth    = local.auth_domain
    profile = local.profile_domain
    socket  = local.socket_domain
  }
}

resource "google_dns_record_set" "services" {
  for_each     = local.service_subdomains
  name         = "${each.value}."
  managed_zone = google_dns_managed_zone.main.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["ghs.googlehosted.com."]
  project      = var.project_id
}

# -----------------------------------------------
# Output the nameservers — you'll need these for Squarespace
# -----------------------------------------------
output "nameservers" {
  description = "Set these as your nameservers in Squarespace"
  value       = google_dns_managed_zone.main.name_servers
}