output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.crud.id}.execute-api.${var.region}.amazonaws.com/prod"
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}
