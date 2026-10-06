# App configuration lives in SSM under ${var.ssm_prefix}. The Lambda's bootstrap.js loads every
# parameter under this path into env at cold start, and node-config reads them.
#
# Two kinds:
#  - Managed here (non-secret or Terraform-generated): MONGO_URL, S3 + CORS settings.
#  - Placeholder + ignore_changes (real secrets): you set the values once via `aws ssm put-parameter`,
#    so they never live in a local file or in Terraform state.

# Terraform-generated connection string.
resource "aws_ssm_parameter" "mongo_url" {
  name  = "${var.ssm_prefix}/MONGO_URL"
  type  = "SecureString"
  value = local.mongodb_uri
}

# Non-secret operational config, managed from variables.
resource "aws_ssm_parameter" "config" {
  for_each = {
    AWS_S3_BUCKET_NAME = var.s3_bucket_name
    AWS_S3_REGION      = var.aws_region
    AWS_S3_API_VERSION = "2006-03-01"
    CORS_WHITELIST     = "https://${var.subdomain}.${var.domain}"
  }
  name  = "${var.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}

# Secrets - created empty, you set the real values via `aws ssm put-parameter` so they never live
# in a local file or in Terraform state.
#   Used by the app today: SESSION_SECRET (session signing), GOOGLE_CLIENT_ID (Google ID-token verify).
#   Declared in config but NOT read by current code: GOOGLE_CLIENT_SECRET (only for server-side OAuth
#   code exchange), JWT_CLIENT_SECRET (app uses cookie sessions, not JWTs). Left here for future use.
resource "aws_ssm_parameter" "secrets" {
  for_each = toset([
    "SESSION_SECRET",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "JWT_CLIENT_SECRET",
  ])
  name  = "${var.ssm_prefix}/${each.key}"
  type  = "SecureString"
  value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}
