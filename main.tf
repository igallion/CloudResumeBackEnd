terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.26.0"
    }
  }

  backend "s3" {
    bucket = "ilg-tf-test-config"
    key    = "backend/terraform.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 1.14.3"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "CloudResumeVisitorsTerraform"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "stat"

  attribute {
    name = "stat"
    type = "S"
  }
  /*
  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }
  */
  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }

}

resource "aws_lambda_function" "lambda_Cloud_Resume_Counter_Terraform" {
  function_name    = "CloudResumeCounterTerraform"
  filename         = data.archive_file.lambda_zip_file.output_path
  source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.CloudResumeCounterTerraform-role.arn
  runtime          = "python3.14"
}

data "archive_file" "lambda_zip_file" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "CloudResumeCounterTerraform-role" {
  name               = "CloudResumeCounterTerraform-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "CloudResumeVisitorsTerraform" {
  name = "CloudResumeVisitorsTerraform"
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy_terraform" {
  name   = "lambda-dynamodb-policy-terraform"
  role   = aws_iam_role.CloudResumeCounterTerraform-role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "logs:CreateLogGroup"
            ],
            "Resource": [
                "${aws_dynamodb_table.basic-dynamodb-table.arn}",
                "${aws_cloudwatch_log_group.CloudResumeVisitorsTerraform.arn}"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "${aws_cloudwatch_log_group.CloudResumeVisitorsTerraform.arn}"
        }
    ]
}
EOF
}

resource "aws_api_gateway_rest_api" "CloudResumeCounterTerraform" {
  name        = "CloudResumeCounterTerraform"
  description = "API gateway deployed from Terraform for Cloud Resume Project"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  parent_id   = aws_api_gateway_rest_api.CloudResumeCounterTerraform.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_Cloud_Resume_Counter_Terraform.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  resource_id   = aws_api_gateway_rest_api.CloudResumeCounterTerraform.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_Cloud_Resume_Counter_Terraform.invoke_arn
}

resource "aws_api_gateway_deployment" "CloudResumeAPIGatewayDeployment" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.CloudResumeCounterTerraform.id
  #stage_name  = "CloudResumeCounterTerraform"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_Cloud_Resume_Counter_Terraform.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.CloudResumeCounterTerraform.execution_arn}/*/*"
}

output "dynamodb_basic_dynamodb_table_arn" {
  value       = aws_dynamodb_table.basic-dynamodb-table.arn
  description = "The ARN of the user count DynamoDB table"
}

output "lambda_processing_arn" {
  value       = aws_lambda_function.lambda_Cloud_Resume_Counter_Terraform.arn
  description = "The ARN of the Lambda function processing the DynamoDB stream"
}

output "cloudwatch_log_group_arn" {
  value       = aws_cloudwatch_log_group.CloudResumeVisitorsTerraform.arn
  description = "The ARN of the cloudwatch group"
}

output "base_url" {
  value       = aws_api_gateway_deployment.CloudResumeAPIGatewayDeployment.invoke_url
  description = "Base URL of CloudResumeAPIGateway Deployment"
}
