# Remote state (S3) - single machine

State lives in an encrypted, versioned S3 bucket instead of a local file. Even with one machine,
this is the safety net: if the machine is wiped, you reinstall, `terraform init`, and your state is
still in S3 - no manual re-import. Versioning also lets you roll back a bad state.

A DynamoDB lock table is included to prevent a corrupted state if two runs ever overlap (~$0). It's
optional for a single machine but harmless.

## Step 1 - Create the bucket + lock table (once)

Pick any globally-unique, lowercase name (S3 names are unique across ALL AWS accounts). Avoid the
account ID. If the name is already taken you'll get `BucketAlreadyExists` - just pick another.

```sh
BUCKET="fennec-terraform-state"    # must match backend.tf; change if already taken globally

aws s3api create-bucket --bucket "$BUCKET" --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

# Versioning = rollback / corruption protection. Block public access. (SSE-S3 encryption is on by default.)
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Lock table (on-demand billing = ~$0 at this usage).
aws dynamodb create-table --table-name fennec-tflock --region us-east-2 \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then edit `backend.tf` and set `bucket` to the `$BUCKET` value above.

## Step 2 - Migrate your existing local state up to S3

Run on the machine that currently holds `terraform.tfstate`:

```sh
terraform init -migrate-state
# Terraform sees the new S3 backend and asks:
#   "Do you want to copy existing state to the new backend?"  -> yes
terraform state list   # confirm your resources are listed
```

The local `terraform.tfstate` is no longer used after this (safe to delete).

## Disaster recovery - machine wiped

1. Reinstall Terraform + AWS credentials on the new machine.
2. Clone this repo (it has `backend.tf`).
3. `terraform init`  -> pulls state straight from S3.
4. `terraform plan`  -> "No changes" confirms you're back in sync.

No re-import, no lost state. If a bad apply ever corrupts state, restore a prior version from the
bucket's version history.
