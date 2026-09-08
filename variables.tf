variable "aws_region" {
  description = "AWS region for the Lambda backend."
  type        = string
  default     = "us-east-2"
}

variable "app_name" {
  description = "Short name used to prefix AWS/Cloudflare resources."
  type        = string
  default     = "fennec"
}

# --- Cloudflare ---

variable "cloudflare_api_token" {
  description = "Cloudflare API token scoped to Zone:DNS edit, Pages edit, Account read."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the zone and Pages project."
  type        = string
}

variable "domain" {
  description = "Root domain already managed in Cloudflare (e.g. example.com)."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the new SPA (e.g. app2 -> app2.example.com)."
  type        = string
  default     = "app2"
}

# --- MongoDB Atlas ---

variable "mongodbatlas_public_key" {
  description = "Atlas API public key."
  type        = string
  sensitive   = true
}

variable "mongodbatlas_private_key" {
  description = "Atlas API private key."
  type        = string
  sensitive   = true
}

variable "mongodbatlas_project_id" {
  description = "Atlas project ID that holds the existing cluster."
  type        = string
}

variable "mongodbatlas_cluster_name" {
  description = "Name of the existing Atlas cluster to connect to."
  type        = string
}

variable "db_username" {
  description = "SCRAM database user Terraform will create."
  type        = string
  default     = "fennec_app"
}

variable "db_name" {
  description = "Application database name (used for readWrite scope and the URI path)."
  type        = string
  default     = "fennec"
}

# --- Lambda ---

variable "lambda_memory_mb" {
  description = "Lambda memory in MB (also scales CPU). Sharp image processing needs headroom."
  type        = number
  default     = 1024
}

variable "lambda_timeout_s" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Keep short to avoid storage cost."
  type        = number
  default     = 14
}
