output "backend_api_url" {
  description = "HTTP API Gateway endpoint for the backend (fronted by the Cloudflare proxy in production)."
  value       = aws_apigatewayv2_api.backend.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name - used by the GitHub Actions deploy workflow."
  value       = aws_lambda_function.backend.function_name
}

output "ci_deploy_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC. Set as the AWS_DEPLOY_ROLE secret/var in the repo."
  value       = aws_iam_role.ci_deploy.arn
}

output "spa_url" {
  description = "Public URL of the new SPA."
  value       = "https://${var.subdomain}.${var.domain}"
}

output "pages_project_name" {
  description = "Cloudflare Pages project name for `wrangler pages deploy`."
  value       = cloudflare_pages_project.spa.name
}

output "db_username" {
  description = "Atlas database user created for the app."
  value       = mongodbatlas_database_user.app.username
}

output "ssm_prefix" {
  description = "SSM path holding the app config/secrets."
  value       = var.ssm_prefix
}

output "ssm_secrets_to_set" {
  description = "SecureString params created empty - set their real values with `aws ssm put-parameter`."
  value       = [for k in keys(aws_ssm_parameter.secrets) : aws_ssm_parameter.secrets[k].name]
}

output "mongodb_uri" {
  description = "Full MongoDB Atlas connection string."
  value       = local.mongodb_uri
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL for the backend image. Used by the deploy workflow."
  value       = aws_ecr_repository.backend.repository_url
}
