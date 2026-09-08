# Direct-upload Pages project for the new SPA. Deploy assets with:
#   wrangler pages deploy ./dist --project-name=<name>
resource "cloudflare_pages_project" "spa" {
  account_id        = var.cloudflare_account_id
  name              = "${var.app_name}-spa"
  production_branch = "main"

  deployment_configs {
    production {
      # Available to the same-origin proxy Pages Function (functions/api/[[path]].js).
      environment_variables = {
        BACKEND_URL  = aws_lambda_function_url.backend.function_url
        PROXY_SECRET = random_password.proxy_secret.result
      }
    }
  }
}

# Bind app2.DOMAIN to the Pages project. Because the zone is on this Cloudflare account,
# Cloudflare automatically creates the proxied CNAME for this custom domain - so no explicit
# cloudflare_record is needed (adding one collides with the auto-created record).
resource "cloudflare_pages_domain" "spa" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.spa.name
  domain       = "${var.subdomain}.${var.domain}"
}
