# fennec infrastructure

Terraform for a $0-at-low-traffic serverless backend and SPA:

```
app2.DOMAIN  (Cloudflare Pages SPA)
   /api/*  --same-origin proxy (Pages Function)-->  AWS Lambda Function URL (Node)
                                                        --> MongoDB Atlas (mongodb+srv, TLS + SCRAM)
```

- Backend: AWS Lambda + Function URL (free tier covers ~1M req/mo).
- Frontend: new subdomain SPA on Cloudflare Pages (additive, existing apps untouched).
- CORS is designed out: SPA and API share one origin via the Cloudflare proxy.
- DB: existing MongoDB Atlas cluster. Terraform creates a scoped user + `0.0.0.0/0` allowlist
  (Lambda egress is dynamic; access is gated by TLS + SCRAM auth).

## Prerequisites

- Terraform >= 1.9, AWS CLI (authenticated, e.g. `awsuse`), Node 22.
- `wrangler` for Pages deploys: `npm i -g wrangler`.
- A Cloudflare API token (Zone:DNS edit, Pages edit, Account read) and account ID.
- An Atlas API key (public + private), the project ID, and the existing cluster name.

## Configure

```sh
cp terraform.tfvars.example terraform.tfvars   # fill in (gitignored)
```

Secrets can also be passed as env vars, e.g. `export TF_VAR_mongodbatlas_private_key=...`.

## Deploy

```sh
# 1. Install backend deps so the Lambda zip includes them.
cd lambda_src && npm ci && cd ..

# 2. Provision everything.
terraform init
terraform apply

# 3. Deploy the SPA. Copy spa_proxy_example/functions/ into your SPA repo first, then:
wrangler pages deploy ./dist --project-name="$(terraform output -raw pages_project_name)"
```

The same-origin proxy needs `spa_proxy_example/functions/api/[[path]].js` present in your SPA
build. Terraform sets the `BACKEND_URL` and `PROXY_SECRET` env vars on the Pages project for it.

## Verify

```sh
# Lambda direct (should return {"status":"ok","db":"connected"}):
curl "$(terraform output -raw lambda_function_url)api/health" -H "x-proxy-secret: <PROXY_SECRET>"

# Same-origin through Cloudflare (no secret header needed - the proxy adds it):
curl "https://app2.DOMAIN/api/health"
```

Then load `https://app2.DOMAIN`, confirm the SPA calls `/api/...` with no CORS errors, and confirm
the pre-existing Cloudflare app still works.

## Cost notes

- Function URL (not API Gateway) = no per-request gateway charge.
- CloudWatch log retention is 14 days to avoid storage creep.
- Expect ~$0 until roughly 1M requests/month.

## Secrets and state

`terraform.tfstate` contains the DB password and connection string. Keep it out of git (already
gitignored) or move to an encrypted remote backend (e.g. S3 + DynamoDB lock) before sharing.
