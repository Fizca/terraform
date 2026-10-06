# Git-connected Pages project for the SPA. Cloudflare builds and deploys on every push to the
# production branch of the client repo. Requires the Cloudflare GitHub app to be authorized on
# the ${var.github_owner} org first (one-time, in the dashboard) - Terraform cannot grant it.
resource "cloudflare_pages_project" "spa" {
  account_id        = var.cloudflare_account_id
  name              = "${var.app_name}-spa"
  production_branch = "main"

  source {
    type = "github"
    config {
      owner                         = var.github_owner
      repo_name                     = var.spa_repo
      production_branch             = "main"
      deployments_enabled           = true
      production_deployment_enabled = true
      preview_deployment_setting    = "none"
    }
  }

  build_config {
    build_command   = "yarn build"
    destination_dir = "dist"
    root_dir        = ""
  }

  deployment_configs {
    production {
      # BACKEND_URL / PROXY_SECRET: runtime wiring for the same-origin proxy Pages Function
      # (functions/api/[[path]].js). REACT_APP_GOOGLE_CLIENT_ID: build-time env for the SPA;
      # kept here (not in client source) so it stays paired with the server's GOOGLE_CLIENT_ID.
      environment_variables = {
        BACKEND_URL                = aws_apigatewayv2_api.backend.api_endpoint
        PROXY_SECRET               = random_password.proxy_secret.result
        REACT_APP_GOOGLE_CLIENT_ID = var.google_client_id
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
