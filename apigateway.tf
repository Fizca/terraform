# Public front door for the backend. Replaces the Lambda Function URL, whose anonymous
# (auth_type NONE) invocation is blocked account-wide in this AWS account. An HTTP API
# reaches the Lambda via execute-api, which that block does not cover.
#
# Reached in practice only through the Cloudflare proxy (functions/api/[[path]].js), which
# forwards same-origin browser traffic server-side and adds the x-proxy-secret header.
resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.app_name}-backend"
  protocol_type = "HTTP"
}

# AWS_PROXY passes the raw request (method, path, headers incl. x-proxy-secret) to the Lambda
# Web Adapter, which runs the Express app unchanged. Payload format 2.0 is the HTTP API default.
resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.backend.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Catch-all: the Express app owns all routing, exactly as it did behind the Function URL.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

# The $default stage serves at the root with no stage prefix in the path, so the Cloudflare
# proxy's path-copying (target.pathname = incoming.pathname) keeps working unchanged.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true
}

# API Gateway needs resource-based permission to invoke the Lambda. Without this the API
# returns 500 with no app logs (the function never runs).
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}
