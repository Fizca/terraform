# Direct-upload Pages project for the SPA. Cloudflare's dashboard no longer offers Pages git
# integration (it funnels new repos into Workers), and the git-integration API is unreliable
# (error 8000011), so the SPA is built and published by a GitHub Actions workflow in the client
# repo (`wrangler pages deploy dist`) on every push to main. Terraform owns the project, its
# runtime env, and the custom domain; CI owns the build + upload.
resource "cloudflare_pages_project" "spa" {
  account_id        = var.cloudflare_account_id
  name              = "${var.app_name}-spa"
  production_branch = "main"

  deployment_configs {
    production {
      # Runtime wiring for the same-origin proxy Pages Function (functions/api/[[path]].js).
      # The SPA's build-time vars (SERVER_URL, REACT_APP_GOOGLE_CLIENT_ID) live in CI, not here.
      environment_variables = {
        BACKEND_URL  = aws_apigatewayv2_api.backend.api_endpoint
        PROXY_SECRET = random_password.proxy_secret.result
      }
    }
  }
}

# Register the custom domain on the Pages project. This only records the intent; it does NOT
# create the DNS record, so the domain stays "Verifying" until the CNAME below exists.
resource "cloudflare_pages_domain" "spa" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.spa.name
  domain       = "${var.subdomain}.${var.domain}"
}

# The darksoda.com zone is managed in this Cloudflare account, so Terraform creates the proxied
# CNAME that points the subdomain at the Pages project and lets the custom domain verify.
data "cloudflare_zone" "root" {
  name = var.domain
}

resource "cloudflare_record" "spa" {
  zone_id = data.cloudflare_zone.root.id
  name    = var.subdomain
  type    = "CNAME"
  value   = "${cloudflare_pages_project.spa.name}.pages.dev"
  proxied = true
}
