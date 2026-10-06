# --- GitHub CI (OIDC) ---

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to deploy the Lambda via OIDC. Must match the repo's exact casing - the OIDC sub claim is case-sensitive."
  type        = string
  default     = "Fizca/server"
}

variable "github_branch" {
  description = "Branch allowed to deploy."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if one already exists in the account."
  type        = bool
  default     = true
}

# --- Lambda Web Adapter ---

variable "lwa_layer_version" {
  description = "Version of the public Lambda Web Adapter x86_64 layer. Check the LWA repo for the latest."
  type        = number
  default     = 28
}

# --- Assets / S3 ---

variable "s3_bucket_name" {
  description = "Existing S3 bucket used for image assets (Terraform grants the Lambda role access; it does not create or destroy the bucket)."
  type        = string
}

# --- App config in SSM ---

variable "ssm_prefix" {
  description = "SSM path prefix under which the app's config/secrets live."
  type        = string
  default     = "/fennec/server"
}
