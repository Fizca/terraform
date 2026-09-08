# URL-safe passwords (alphanumeric only) so they need no encoding in the connection string.
resource "random_password" "db" {
  length  = 28
  special = false
}

# Shared secret so only the Cloudflare proxy can invoke the Lambda Function URL.
resource "random_password" "proxy_secret" {
  length  = 40
  special = false
}

# SCRAM user with readWrite on the application database.
resource "mongodbatlas_database_user" "app" {
  project_id         = var.mongodbatlas_project_id
  username           = var.db_username
  password           = random_password.db.result
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.db_name
  }
}

# Lambda egress IPs are dynamic, so the allowlist is open and access is gated by TLS + SCRAM auth.
resource "mongodbatlas_project_ip_access_list" "anywhere" {
  project_id = var.mongodbatlas_project_id
  cidr_block = "0.0.0.0/0"
  comment    = "fennec Lambda (dynamic egress) - secured by TLS + SCRAM"
}

# Read the existing cluster to build the connection string.
data "mongodbatlas_advanced_cluster" "this" {
  project_id = var.mongodbatlas_project_id
  name       = var.mongodbatlas_cluster_name
}

locals {
  # Take the SRV host from the cluster and splice in credentials + database + options.
  atlas_srv_host = data.mongodbatlas_advanced_cluster.this.connection_strings[0].standard_srv

  mongodb_uri = "${replace(
    local.atlas_srv_host,
    "mongodb+srv://",
    "mongodb+srv://${var.db_username}:${random_password.db.result}@"
  )}/${var.db_name}?retryWrites=true&w=majority&appName=${var.app_name}"
}
