output "lambda_function_url" {
  description = "Direct Lambda HTTPS endpoint (fronted by the Cloudflare proxy in production)."
  value       = aws_lambda_function_url.backend.function_url
}

output "spa_url" {
  description = "Public URL of the new SPA."
  value       = "https://${var.subdomain}.${var.domain}"
}

output "pages_project_name" {
  description = "Cloudflare Pages project name for `wrangler pages deploy`."
  value       = cloudflare_pages_project.spa.name
}

output "pages_default_subdomain" {
  description = "Default *.pages.dev host for the project."
  value       = cloudflare_pages_project.spa.subdomain
}

output "db_username" {
  description = "Atlas database user created for the app."
  value       = mongodbatlas_database_user.app.username
}

output "ssm_mongodb_uri_param" {
  description = "SSM parameter name holding the connection string."
  value       = aws_ssm_parameter.mongodb_uri.name
}

output "mongodb_uri" {
  description = "Full MongoDB Atlas connection string."
  value       = local.mongodb_uri
  sensitive   = true
}
