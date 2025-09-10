# DynamoDB Table
resource "aws_dynamodb_table" "crud" {
  name         = "crud-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}


# Lambda Function
resource "aws_lambda_function" "crud" {
  function_name    = "serverless_crud"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.crud.name
      ALLOWED_ORIGIN = aws_cloudfront_distribution.frontend.domain_name
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "crud" {
  name        = "crud-api"
  description = "CRUD API with Lambda backend"
}

# Root resource /items
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.crud.id
  parent_id   = aws_api_gateway_rest_api.crud.root_resource_id
  path_part   = "items"
}

# /items/{id}
resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.crud.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# Methods
resource "aws_api_gateway_method" "items_post" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "items_get" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_get" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_put" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_delete" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# Integrations
resource "aws_api_gateway_integration" "items_post" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.items_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud.invoke_arn
}

resource "aws_api_gateway_integration" "items_get" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.items_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud.invoke_arn
}

resource "aws_api_gateway_integration" "item_get" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.item_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud.invoke_arn
}

resource "aws_api_gateway_integration" "item_put" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.item_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud.invoke_arn
}

resource "aws_api_gateway_integration" "item_delete" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.item_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud.invoke_arn
}

# Lambda permission
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crud.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.crud.execution_arn}/*/*"
}
#API Gateway Deployment + Stage
resource "aws_api_gateway_deployment" "crud" {
  rest_api_id = aws_api_gateway_rest_api.crud.id

  depends_on = [
    aws_api_gateway_integration.items_post,
    aws_api_gateway_integration.items_get,
    aws_api_gateway_integration.item_get,
    aws_api_gateway_integration.item_put,
    aws_api_gateway_integration.item_delete
  ]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  deployment_id = aws_api_gateway_deployment.crud.id
  stage_name    = "prod"
}


# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "serverless-frontend-${random_id.bucket_id.hex}"

  tags = {
    Name        = "frontend"
    Environment = "dev"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket_acl" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  acl    = "public-read"
}


resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


# Replace API URL inside index.html
data "template_file" "frontend" {
  template = file("${path.module}/frontend/index.html")

  vars = {
    api_url = "https://${aws_api_gateway_rest_api.crud.id}.execute-api.${var.region}.amazonaws.com/prod"
  }
}


resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  content      = data.template_file.frontend.rendered
  content_type = "text/html"
}


# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "s3-frontend"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-frontend"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
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
