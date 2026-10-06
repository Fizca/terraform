# Bootstrap package. Terraform only needs a valid zip to CREATE the function; the real code is
# deployed by GitHub Actions (see ignore_changes below). The placeholder is dependency-free so the
# first `terraform apply` works without an npm install.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/.build/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.app_name}-backend"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "backend" {
  function_name = "${var.app_name}-backend"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs22.x"
  handler       = "run.sh" # Lambda Web Adapter startup script
  memory_size   = var.lambda_memory_mb
  timeout       = var.lambda_timeout_s

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # Lambda Web Adapter layer - runs the Express app unchanged.
  layers = [
    "arn:aws:lambda:${var.aws_region}:753240598075:layer:LambdaAdapterLayerX86:${var.lwa_layer_version}",
  ]

  environment {
    variables = {
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
      PORT                    = "8080"
      SSM_PREFIX              = var.ssm_prefix
      # Optional: enforce in an Express middleware so only the Cloudflare proxy can reach the API.
      PROXY_SECRET = random_password.proxy_secret.result
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda,
  ]

  # CI (GitHub Actions) owns the code; Terraform owns the infra + env. Don't fight over code.
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}
