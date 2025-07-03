# DynamoDB table for URL mappings
resource "aws_dynamodb_table" "urls" {
  name         = "${local.name_prefix}-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"
  attribute {
    name = "short_code"
    type = "S"
  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# Cognito User Pool for authentication
resource "aws_cognito_user_pool" "users" {
  name = "${local.name_prefix}-users"
}
resource "aws_cognito_user_pool_client" "app" {
  name             = "${local.name_prefix}-app-client"
  user_pool_id     = aws_cognito_user_pool.users.id
  generate_secret  = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# IAM Policy for Lambda assume
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_ddb" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["dynamodb:PutItem","dynamodb:GetItem"],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.urls.arn
      }
    ]
  })
}

# Package Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.selected.dir
  output_path = local.selected.zip
}

# Lambda function
resource "aws_lambda_function" "shortener" {
  function_name = "${local.name_prefix}-fn"
  filename      = data.archive_file.lambda_zip.output_path
  handler       = local.selected.handler
  runtime       = local.selected.runtime
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME   = aws_dynamodb_table.urls.name
      USER_POOL_ID = aws_cognito_user_pool.users.id
      REGION       = var.aws_region
    }
  }

  tracing_config { mode = "Active" }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
}
# JWT authorizer
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id             = aws_apigatewayv2_api.http_api.id
  name               = "cognito-authorizer"
  authorizer_type    = "JWT"
  identity_sources   = ["$request.header.Authorization"]
  jwt_configuration {
    issuer   = aws_cognito_user_pool.users.endpoint
    audience = [aws_cognito_user_pool_client.app.id]
  }
}
# Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.shortener.invoke_arn
}
# Routes
resource "aws_apigatewayv2_route" "shorten" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "POST /shorten"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  authorization_type = "JWT"
}
resource "aws_apigatewayv2_route" "redirect" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /{code}"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "NONE"
}
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = local.env
  auto_deploy = true
}

# WAF Rate Limiting
resource "aws_wafv2_web_acl" "waf" {
  name  = "${local.name_prefix}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rateLimit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "wafAll"
  }
}

resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = aws_apigatewayv2_stage.stage.execution_arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}

# CloudFront CDN
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    # Remove protocol prefix from invoke URL
    domain_name = replace(aws_apigatewayv2_stage.stage.invoke_url, "https?://", "")
    origin_id   = "api-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = ""

  default_cache_behavior {
    target_origin_id       = "api-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers      = ["Authorization"]
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "url" {
  value = aws_apigatewayv2_stage.stage.invoke_url
}