terraform {
  backend "s3" {
    # NOTE: backend blocks cannot use variables - these must be literal values.
    # Any globally-unique, lowercase name works. Avoid the account ID (semi-sensitive identifier).
    # If this name is already taken globally, pick another (e.g. add a project word, not your ID).
    bucket       = "fennec-terraform-state"
    key          = "fennec/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
