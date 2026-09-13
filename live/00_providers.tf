terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  access_key = var.localstack_enabled ? "test" : null
  secret_key = var.localstack_enabled ? "test" : null

  endpoints {
    ec2           = var.localstack_enabled ? var.localstack_endpoint : null
    eks           = var.localstack_enabled ? var.localstack_endpoint : null
    elbv2         = var.localstack_enabled ? var.localstack_endpoint : null
    iam           = var.localstack_enabled ? var.localstack_endpoint : null
    identitystore = var.localstack_enabled ? var.localstack_endpoint : null
    organizations = var.localstack_enabled ? var.localstack_endpoint : null
    s3            = var.localstack_enabled ? var.localstack_endpoint : null
    ssoadmin      = var.localstack_enabled ? var.localstack_endpoint : null
    sts           = var.localstack_enabled ? var.localstack_endpoint : null
  }
}
