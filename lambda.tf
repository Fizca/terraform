resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.app_name}-backend"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "backend" {
  function_name = "${var.app_name}-backend"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"
  architectures = ["x86_64"]
  memory_size   = var.lambda_memory_mb
  timeout       = var.lambda_timeout_s

  # The Lambda Web Adapter is baked into the image at /opt/extensions/, so no
  # layer or exec wrapper is needed here.
  environment {
    variables = {
      PORT       = "8080"
      SSM_PREFIX = var.ssm_prefix
      # Optional: enforce in an Express middleware so only the Cloudflare proxy can reach the API.
      PROXY_SECRET = random_password.proxy_secret.result
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda,
  ]

  # CI owns the running image via update-function-code; Terraform only sets the
  # create-time anchor (var.image_tag). Don't fight over the tag.
  lifecycle {
    ignore_changes = [image_uri]
  }
}
