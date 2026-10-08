# The ECR repository is owned by the bootstrap layer (terraform/bootstrap). The
# app layer only reads it. This enforces the create order: the lookup fails
# loudly ("repository not found") if the bootstrap layer has not been applied,
# instead of letting the Lambda create against a missing image.
data "aws_ecr_repository" "backend" {
  name = "${var.app_name}-backend"
}
