data "aws_caller_identity" "current" {}

variable "customer_name" {
  type = string
  default = "demo"
}


#Lambda
resource "aws_lambda_function" "hello_world_lambda" {
  filename      = "hello_world_lambda.zip"
  function_name = "${var.customer_name}_helloWorldLambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "hello_world_lambda.handler"
  runtime       = "python3.8"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.customer_name}_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com",
      },
    }],
  })
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "${var.customer_name}_AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.hello_world_api.id}/*/${aws_api_gateway_method.hello_world_method.http_method}${aws_api_gateway_resource.hello_world_resource.path}"
}

# API Gateway
resource "aws_api_gateway_rest_api" "hello_world_api" {
  name        = "${var.customer_name}_hello_world_api"
  description = "API for Hello World Lambda"
}

resource "aws_api_gateway_resource" "hello_world_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  parent_id   = aws_api_gateway_rest_api.hello_world_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_world_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api.id
  resource_id   = aws_api_gateway_resource.hello_world_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_world_api.id
  resource_id             = aws_api_gateway_resource.hello_world_resource.id
  http_method             = aws_api_gateway_method.hello_world_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "hello_world_deployment" {
  depends_on      = [aws_api_gateway_integration.hello_world_integration]
  rest_api_id      = aws_api_gateway_rest_api.hello_world_api.id
  stage_name       = var.customer_name
  description      = "Production Deployment"
}

output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.hello_world_deployment.invoke_url}${aws_api_gateway_resource.hello_world_resource.path}"
}

