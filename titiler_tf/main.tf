# ==============================================================================
# 1. Provider and OpenTofu Setup
# ==============================================================================
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Replace with your target AWS Region
}

# ==============================================================================
# 2. Package Custom Lambda Function Source Code
# ==============================================================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/tmp/lambda_function.zip"
}

# ==============================================================================
# 3. Podman Compile Workflow (Natively compiles Github fork via local-exec)
# ==============================================================================
resource "null_resource" "build_compiled_layer" {
  triggers = {
    # Re-run the podman layer build whenever the Dockerfile changes
    dockerfile_hash = filemd5("${path.module}/layer_build/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOT
      # Ensure output directories exist locally
      mkdir -p ${path.module}/tmp

      # Clean up any lingering container names from previous failed runs
      podman rm -f layer_container_temp 2>/dev/null || true

      # 1. Build the container image using Podman
      podman build -t lambda-compiled-layer-builder ./layer_build
      
      # 2. Spin up a temporary stopped container instance 
      podman create --name layer_container_temp lambda-compiled-layer-builder
      
      # 3. Use Podman CP to bypass volume permission traps and pull zip to host
      podman cp layer_container_temp:/build/layer.zip ${path.module}/tmp/layer.zip
      
      # 4. Remove the temporary instance
      podman rm layer_container_temp
    EOT
  }
}

# ==============================================================================
# 4. AWS Lambda Layer Resource Definition
# ==============================================================================
resource "aws_lambda_layer_version" "compiled_git_layer" {
  depends_on = [null_resource.build_compiled_layer]

  filename            = "${path.module}/tmp/layer.zip"
  layer_name          = "my-compiled-podman-git-layer"
  compatible_runtimes = ["python3.12"]
  description         = "Natively compiled third party library from custom GitHub fork using Podman"
}

# ==============================================================================
# 5. IAM Infrastructure Role & System Permissions
# ==============================================================================
resource "aws_iam_role" "lambda_role" {
  name = "python-lambda-execution-role-podman"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ==============================================================================
# 6. Primary AWS Lambda Function 
# ==============================================================================
resource "aws_lambda_function" "python_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  function_name = "my-podman-compiled-python-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30 
  memory_size   = 256

  # Injecting our Podman compiled GitHub dependency layer
  layers        = [aws_lambda_layer_version.compiled_git_layer.arn]

  depends_on = [aws_iam_role_policy_attachment_lambda_logs]
}

# ==============================================================================
# 7. Deployment Metadata Outputs
# ==============================================================================
output "lambda_arn" {
  value       = aws_lambda_function.python_lambda.arn
  description = "The Amazon Resource Name of the deployed Lambda function."
}

output "layer_arn" {
  value       = aws_lambda_layer_version.compiled_git_layer.arn
  description = "The Amazon Resource Name of the deployed Lambda Layer."
}
