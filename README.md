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

The backend runs from a container image on Lambda. An image-based Lambda must reference an image that
already exists in private ECR, which Terraform cannot synthesize. To keep the bootstrap a set of clean
full applies (no `-target`), Terraform is split into two layers with separate state:

- `bootstrap/` creates the ECR repository and its lifecycle policy.
- the root module creates everything else (Lambda, API Gateway, IAM, SSM, Atlas user, Cloudflare Pages)
  and reads the repo through a `data "aws_ecr_repository"` source. That lookup fails loudly if the
  bootstrap layer has not been applied, which enforces the order.

### First-time bootstrap

Two full applies with an image push between them. Run everything from this `terraform` directory, with
the AWS CLI authenticated (`awsuse`, region us-east-2) and Docker running. `$SRV` is the server repo
(adjust the path if it is not a sibling).

```sh
# 1. Create the ECR repository (bootstrap layer).
cd bootstrap
terraform init
terraform apply
cd ..

# 2. Build and push the seed image to ECR.
SRV=../server
SHA=$(git -C "$SRV" rev-parse HEAD)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.us-east-2.amazonaws.com"
aws ecr get-login-password --region us-east-2 \
  | docker login --username AWS --password-stdin "$REGISTRY"
docker buildx build \
  --platform linux/amd64 --provenance=false --sbom=false \
  -t "$REGISTRY/fennec-backend:$SHA" --push "$SRV"

# 3. Pin the seed tag so the app layer creates the function from it.
#    Add this line to terraform.tfvars:  image_tag = "<the SHA printed above>"

# 4. Provision everything else (app layer).
terraform init
terraform apply
```

Notes:

- `--platform linux/amd64` matches the x86_64 Lambda runtime; on Apple Silicon it builds under
  emulation. `--provenance=false --sbom=false` keeps the push a single image manifest, which Lambda
  requires (the default buildx output is a multi-manifest index Lambda rejects).
- `image_tag` is only the create-time anchor. Routine backend deploys run in the server repo via
  `.github/workflows/deploy.yml`, which builds a new SHA-tagged image and calls `update-function-code`.
  Terraform ignores `image_uri` after creation, so it never fights CI over the running image.
- The SSM secrets (`SESSION_SECRET`, `GOOGLE_CLIENT_ID`) are still set once by hand after the apply.
  See "Set once by hand" and "Session Secret" below.
- Tear down in reverse: `terraform destroy` here (root), then `cd bootstrap && terraform destroy`.

### Frontend (Cloudflare Pages)

Cloudflare's dashboard no longer offers Pages git integration (it steers new repos into Workers),
and the git-integration API is unreliable (error `8000011`). So the Pages project is a direct-upload
project: Terraform (root layer) provisions it, its runtime env vars, and the custom domain; a GitHub
Actions workflow in the client repo builds and publishes it on every push to `main`.

The SPA then deploys from the client repo via `.github/workflows/deploy.yml`: on every push to
`main` it runs `yarn build` and `wrangler pages deploy dist --project-name=fennec-spa`, which uploads
both the SPA and the same-origin proxy at `functions/api/[[path]].js`. Terraform sets the proxy's
runtime env vars (`BACKEND_URL`, `PROXY_SECRET`) on the Pages project; the SPA's build-time vars
(`SERVER_URL`, `REACT_APP_GOOGLE_CLIENT_ID`) live in the workflow. `spa_proxy_example/` here is the
reference copy of that proxy.

The client repo needs these set once:

- `secrets.CLOUDFLARE_API_TOKEN` - token with Account > Cloudflare Pages > Edit
- `secrets.CLOUDFLARE_ACCOUNT_ID` - the Cloudflare account id
- `vars.REACT_APP_GOOGLE_CLIENT_ID` - public Google OAuth client id (must match the server's)

## Configuration reference: what to set vs leave alone

The app's runtime config lives in SSM under `/fennec/server`. There are two kinds of values, handled
very differently.

### Terraform-managed (do NOT edit by hand)

These are generated or derived from `terraform.tfvars` and variables. Change them by editing the
variable and re-running `terraform apply`, never with `aws ssm put-parameter`. A manual edit drifts
from state and gets reverted or confuses the next apply.

| Value | Source |
|-------|--------|
| `MONGO_URL` | built from the cluster, `db_name`, and a generated DB password |
| `AWS_S3_BUCKET_NAME`, `AWS_S3_REGION`, `AWS_S3_API_VERSION` | from variables |
| `CORS_WHITELIST` | `https://${subdomain}.${domain}` |
| `BACKEND_URL`, `PROXY_SECRET` (on the Pages project) | API Gateway endpoint and a generated secret |

The database the app reads is the `db_name` variable (currently `myFirstDatabase`). To point the app
at a different database, edit `db_name` in `terraform.tfvars` and re-apply. That updates both
`MONGO_URL` and the Atlas user's `readWrite` scope. Do not hand-edit `MONGO_URL`.

### Set once by hand (Terraform creates them empty)

Terraform creates these as empty `REPLACE_ME` SecureStrings with `ignore_changes = [value]`. You set
the real value once with `aws ssm put-parameter --overwrite`, and Terraform never touches it again.

| Secret | Set it? | Notes |
|--------|---------|-------|
| `SESSION_SECRET` | Yes | random value, see the Session Secret section below |
| `GOOGLE_CLIENT_ID` | Yes | must equal the client's `REACT_APP_GOOGLE_CLIENT_ID`, see below |
| `GOOGLE_CLIENT_SECRET` | No | leave `REPLACE_ME`. The code verifies ID tokens offline, no code exchange |
| `JWT_CLIENT_SECRET` | No | leave `REPLACE_ME`. The app uses cookie sessions, not JWTs |

After changing any SSM value, force a Lambda cold start so it reloads. SSM is read only at cold start,
so a warm Lambda keeps the old value until the environment recycles.

```bash
aws lambda update-function-configuration \
  --function-name fennec-backend \
  --description "reload SSM $(date -u +%FT%TZ)" \
  --region us-east-2
```

### Google client id (the server and client must match)

The SPA signs the user in with its `REACT_APP_GOOGLE_CLIENT_ID` (a GitHub repo variable in the client
repo), and the server verifies the resulting ID token against its `GOOGLE_CLIENT_ID` (SSM). These must
be the same Google OAuth web client id. If they differ, the server throws
`payload audience != requiredAudience` and login fails.

```bash
# Point the server at the same id the client builds with:
aws ssm put-parameter --name /fennec/server/GOOGLE_CLIENT_ID \
  --type SecureString --value "<client-id>.apps.googleusercontent.com" \
  --overwrite --region us-east-2

# Confirm the two agree (bundle value should equal the SSM value):
curl -s https://fennec.darksoda.com/bundle.js \
  | grep -oE '[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com' | head -1
aws ssm get-parameter --name /fennec/server/GOOGLE_CLIENT_ID \
  --with-decryption --region us-east-2 --query Parameter.Value --output text
```

The client id is public (it ships in the SPA bundle). Only the client secret would be sensitive, and
this flow does not use it.

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
