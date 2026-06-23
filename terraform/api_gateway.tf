resource "aws_apigatewayv2_api" "dashboard" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Project = var.project
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.dashboard.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Project = var.project
  }
}

resource "aws_apigatewayv2_integration" "api_handler" {
  api_id                 = aws_apigatewayv2_api.dashboard.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "violations_get" {
  api_id    = aws_apigatewayv2_api.dashboard.id
  route_key = "GET /violations"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler.id}"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dashboard.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.dashboard.api_endpoint
}

output "dashboard_url" {
  value = "http://${aws_s3_bucket_website_configuration.dashboard.website_endpoint}"
}