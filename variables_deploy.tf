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

# --- Container image ---

variable "image_tag" {
  description = "Image tag the Lambda is created from (the seed commit SHA). CI deploys new tags out of band via update-function-code; this is only Terraform's create-time anchor."
  type        = string
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
