terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  description = "Región AWS donde desplegar"
  type        = string
  default     = "us-east-1"
}

# DynamoDB Table for reminders
resource "aws_dynamodb_table" "reminders" {
  name         = "Reminders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# IAM Role y policy para Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "reminder-api-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.reminders.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "reminder-api-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# # Package Lambda code
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   source_dir  = "../backend"
#   output_path = "../backend/deploy/api.zip"
#   excludes    = [
#     "**/.venv/**",
#     "**/__pycache__/**",
#     "**/deploy/**"
#   ]
# }

resource "aws_lambda_function" "api" {
  function_name    = "reminder-api"
  handler          = "main.handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "../backend/function3.zip"
  source_code_hash = filebase64sha256("../backend/function3.zip")

  timeout      = 30    # antes era 3, ahora 30 segundos
  memory_size  = 256   # opcional: un poco más de RAM ↗ también ayuda a acelerar las llamadas de red

  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.reminders.name
    }
  }
}

# HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "reminder-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Package and publish SPA static assets
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "reminder-webapp-frontend-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "reminder-webapp-frontend"
    Environment = "production"
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI para distribución de Reminder Webapp"
}

# Política del bucket para que solo la OAI pueda leer objetos
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipalReadOnly"
      Effect    = "Allow"
      Principal = {
        AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
      }
      Action   = ["s3:GetObject"]
      Resource = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
    }]
  })
}

# Configuración de website (index y error)
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

# CloudFront distribution para servir SPA
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-Frontend"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-Frontend"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "reminder-webapp-frontend-cdn"
  }
}

# Outputs
output "api_endpoint" {
  description = "URL de tu HTTP API"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "frontend_bucket_name" {
  description = "Nombre del bucket S3 de front-end"
  value       = aws_s3_bucket.frontend_bucket.id
}

output "frontend_url" {
  description = "Dominio de CloudFront para la SPA estática"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}



#Schduler

resource "aws_lambda_layer_version" "twilio" {
  layer_name          = "reminder-twilio"
  compatible_runtimes = ["python3.10"]
  filename            = "../backend/scheduler/twilio-layer.zip"
}

# 1) Archive del scheduler
# data "archive_file" "scheduler_zip" {
#   type        = "zip"
#   source_dir  = "../backend"
#   output_path = "../backend/scheduler/scheduler-code.zip"
#   excludes    = ["**/.venv/**","**/__pycache__/**","**/deploy/api.zip"]
# }

# 2) IAM Role para el scheduler
resource "aws_iam_role" "scheduler_role" {
  name = "reminder-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "scheduler_policy" {
  name   = "reminder-scheduler-policy"
  role   = aws_iam_role.scheduler_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# 3) Lambda function del scheduler
resource "aws_lambda_function" "scheduler" {
  function_name = "reminder-scheduler"
  handler       = "scheduler.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.scheduler_role.arn

  filename         = "../backend/scheduler/scheduler2.zip"
  source_code_hash = filebase64sha256("../backend/scheduler/scheduler2.zip")

  timeout      = 30    # antes era 3, ahora 30 segundos
  memory_size  = 256   # opcional: un poco más de RAM ↗ también ayuda a acelerar las llamadas de red

  environment {
    variables = {
      DYNAMO_TABLE            = aws_dynamodb_table.reminders.name
      TWILIO_ACCOUNT_SID      = var.twilio_account_sid
      TWILIO_AUTH_TOKEN       = var.twilio_auth_token
      TWILIO_WHATSAPP_FROM    = var.twilio_whatsapp_from
    }
  }

#   layers = [
#     aws_lambda_layer_version.twilio.arn,
#   ]
}

# 4) EventBridge rule every 5 minutos
resource "aws_cloudwatch_event_rule" "every_5_minutes" {
  name                = "Every1Minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "invoke_scheduler" {
  rule      = aws_cloudwatch_event_rule.every_5_minutes.name
  target_id = "scheduler"
  arn       = aws_lambda_function.scheduler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvokeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_5_minutes.arn
}

variable "twilio_account_sid" {
  type = string
}
variable "twilio_auth_token" {
  type = string
  sensitive = true
}
variable "twilio_whatsapp_from" {
  type = string
}
