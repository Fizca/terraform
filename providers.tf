provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project   = "fennec"
      managedBy = "terraform"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "mongodbatlas" {
  public_key  = var.mongodbatlas_public_key
  private_key = var.mongodbatlas_private_key
}
