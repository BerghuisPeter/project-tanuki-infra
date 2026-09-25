# -----------------------------------------------
# GCP Pub/Sub Infrastructure & IAM for Enrichment Pipeline
# -----------------------------------------------

resource "google_pubsub_topic" "enrichment_requests" {
  name = var.enrichment_topic_name
}

resource "google_service_account" "pubsub_invoker" {
  account_id   = "tanuki-pubsub-invoker"
  display_name = "Pub/Sub OIDC Invoker Service Account"
}

resource "google_pubsub_subscription" "enrichment_push_subscription" {
  name  = "enrichment-requests-push-sub"
  topic = google_pubsub_topic.enrichment_requests.name

  push_config {
    push_endpoint = "${module.enrichment_worker.service_url}/enrich"

    oidc_token {
      service_account_email = google_service_account.pubsub_invoker.email
    }
  }

  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_cloud_run_v2_service_iam_member" "enrichment_invoker" {
  project  = module.enrichment_worker.project
  location = module.enrichment_worker.location
  name     = module.enrichment_worker.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_invoker.email}"
}

resource "google_pubsub_topic_iam_member" "publisher" {
  topic  = google_pubsub_topic.enrichment_requests.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.cloudrun_runtime.email}"
}
