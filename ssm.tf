# The Mongo connection string lives in SSM as a SecureString (free) and is read at Lambda cold start.
resource "aws_ssm_parameter" "mongodb_uri" {
  name        = "/${var.app_name}/mongodb_uri"
  description = "MongoDB Atlas connection string for the ${var.app_name} backend."
  type        = "SecureString"
  value       = local.mongodb_uri
}
