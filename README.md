# fennec infrastructure

Terraform for a $0-at-low-traffic serverless backend and SPA:

```
app2.DOMAIN  (Cloudflare Pages SPA)
   /api/*  --same-origin proxy (Pages Function)-->  AWS HTTP API Gateway --> Lambda (Node)
                                                        --> MongoDB Atlas (mongodb+srv, TLS + SCRAM)
```

- Backend: AWS Lambda fronted by an HTTP API Gateway (free tier covers ~1M req/mo).
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

One-time prerequisite: authorize the Cloudflare GitHub app on the `github_owner` org so Pages can
build from the repo. Do this in the Cloudflare dashboard (Workers & Pages, connect to Git).
Terraform cannot grant this.

```sh
# 1. Install backend deps so the Lambda zip includes them.
cd lambda_src && npm ci && cd ..

# 2. Provision everything (creates the git-connected Pages project).
terraform init
terraform apply
```

The SPA then deploys automatically: Cloudflare builds and publishes on every push to the `main`
branch of the client repo (`yarn build`, output `dist/`). The same-origin proxy lives in the client
repo at `functions/api/[[path]].js`; Terraform sets the `BACKEND_URL`, `PROXY_SECRET`, and
`REACT_APP_GOOGLE_CLIENT_ID` env vars on the Pages project. `spa_proxy_example/` here is the
reference copy of that proxy.

## Verify

```sh
# Backend direct via API Gateway (liveness route; should return {"hello":"world"}):
curl "$(terraform output -raw backend_api_url)/" -H "x-proxy-secret: <PROXY_SECRET>"

# Same-origin through Cloudflare (no secret header needed - the proxy adds it):
curl "https://app2.DOMAIN/api/health"
```

Then load `https://app2.DOMAIN`, confirm the SPA calls `/api/...` with no CORS errors, and confirm
the pre-existing Cloudflare app still works.

## Cost notes

- HTTP API Gateway: first 1M requests/month are free, then ~$1 per million.
- CloudWatch log retention is 14 days to avoid storage creep.
- Expect ~$0 until roughly 1M requests/month.

## Secrets and state

State is local only. `terraform.tfstate` lives on the machine that runs `apply` and contains the DB
password and connection string. It is gitignored, so it never leaves the machine. Run Terraform from
that one machine, and back up the file if it matters to you.

### Session Secret

The session secret is uploaded to AWS via terminal.

The secret is set in AWS SSM. The `--overwrite` flag clobbers the value in the secret to replace what terraform entered. Terraform already has the `ignore_changes = [value]` setup, so on future run of terraform this will not change.

```bash
aws ssm put-parameter \
  --name "/fennec/server/SESSION_SECRET" \
  --type SecureString \
  --value "$(openssl rand -base64 48)" \
  --overwrite \
  --region us-east-2
```

The value can then be checked to be set. The return should **NOT** be `REPLACE_ME`. If it returns with that, it means the value was not set.

```bash
aws ssm get-parameter --name /fennec/server/SESSION_SECRET \
  --with-decryption --region us-east-2 \
  --query Parameter.Value --output text
```
