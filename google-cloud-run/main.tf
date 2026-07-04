
# Terraform script for deploying n8n in "Durable mode" on Google Cloud Run
#
# This script is based on the instructions in the n8n documentation:
# https://docs.n8n.io/hosting/installation/server-setups/google-cloud-run.html#durable-mode

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable necessary APIs
resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
}

# Create a random password for the database user
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Create a random encryption key
resource "random_password" "encryption_key" {
  length  = 42
  special = true
}

# Create the Cloud SQL for PostgreSQL instance
resource "google_sql_database_instance" "n8n_db_instance" {
  name             = "n8n-db"
  database_version = "POSTGRES_13"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"
    backup_configuration {
      enabled = false
    }
  }

  deletion_protection = false
}

# Create the n8n database
resource "google_sql_database" "n8n_database" {
  name     = "n8n"
  instance = google_sql_database_instance.n8n_db_instance.name
}

# Create the n8n database user
resource "google_sql_user" "n8n_user" {
  name     = "n8n-user"
  instance = google_sql_database_instance.n8n_db_instance.name
  password = random_password.db_password.result
}

# Store the database password in Secret Manager
resource "google_secret_manager_secret" "n8n_db_password_secret" {
  secret_id = "n8n-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "n8n_db_password_secret_version" {
  secret      = google_secret_manager_secret.n8n_db_password_secret.id
  secret_data = random_password.db_password.result
}

# Store the encryption key in Secret Manager
resource "google_secret_manager_secret" "n8n_encryption_key_secret" {
  secret_id = "n8n-encryption-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "n8n_encryption_key_secret_version" {
  secret      = google_secret_manager_secret.n8n_encryption_key_secret.id
  secret_data = random_password.encryption_key.result
}

# Create a service account for the Cloud Run service
resource "google_service_account" "n8n_service_account" {
  account_id   = "n8n-service-account"
  display_name = "n8n Service Account"
}

# Grant the service account access to the database password secret
resource "google_secret_manager_secret_iam_member" "n8n_db_password_secret_accessor" {
  secret_id = google_secret_manager_secret.n8n_db_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_service_account.email}"
}

# Grant the service account access to the encryption key secret
resource "google_secret_manager_secret_iam_member" "n8n_encryption_key_secret_accessor" {
  secret_id = google_secret_manager_secret.n8n_encryption_key_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_service_account.email}"
}

# Grant the service account the Cloud SQL Client role
resource "google_project_iam_member" "n8n_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.n8n_service_account.email}"
}

# Deploy the n8n Cloud Run service
resource "google_cloud_run_v2_service" "n8n_service" {
  name     = "n8n"
  location = var.region
  ingress = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.n8n_service_account.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.n8n_db_instance.connection_name]
      }
    }

    containers {
      image = "n8nio/n8n:latest"
      command = ["/bin/sh"]
      args    = ["-c", "sleep 5; n8n start"]

      ports {
        container_port = 5678
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          memory = "2Gi"
        }
        cpu_idle = false
      }

      env {
        name  = "N8N_PORT"
        value = "5678"
      }
      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.n8n_database.name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = google_sql_user.n8n_user.name
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${google_sql_database_instance.n8n_db_instance.connection_name}"
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name  = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.n8n_db_password_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.n8n_encryption_key_secret.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.run,
    google_project_service.sqladmin,
    google_project_service.secretmanager,
    google_secret_manager_secret_iam_member.n8n_db_password_secret_accessor,
    google_secret_manager_secret_iam_member.n8n_encryption_key_secret_accessor,
    google_project_iam_member.n8n_cloudsql_client,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "n8n_public_invoker" {
  project  = google_cloud_run_v2_service.n8n_service.project
  location = google_cloud_run_v2_service.n8n_service.location
  name     = google_cloud_run_v2_service.n8n_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Define input variables
variable "project_id" {
  description = "The Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy the resources in."
  type        = string
}

# Output the URL of the Cloud Run service
output "n8n_url" {
  value = google_cloud_run_v2_service.n8n_service.uri
}
