terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.localstack_enabled ? null : var.aws_profile

  access_key = var.localstack_enabled ? "test" : null
  secret_key = var.localstack_enabled ? "test" : null

  endpoints {
    iam = var.localstack_enabled ? var.localstack_endpoint : null
    s3  = var.localstack_enabled ? var.localstack_endpoint : null
    sts = var.localstack_enabled ? var.localstack_endpoint : null
  }
}

module "s3_terraform_state" {
  source = "../modules/s3"
  region = var.aws_region
  bucket = var.state_bucket_name
  status = "Enabled"

  encryption_type = "SSE_S3"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
  # Opcional atualmente para CAs confiáveis pela AWS.
  # Se declarado, precisa ser o thumbprint correto e atualizado.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "TerraformManagement"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_administrator" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


resource "aws_organizations_organization" "org" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  aws_service_access_principals = [
    "controltower.amazonaws.com"
  ]
}


resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "LogArchive"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_account" "audit_account" {
  name      = "Audit"
  email     = var.audit_account_email
  parent_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_account" "log_archive_account" {
  name      = "Log Archive"
  email     = var.log_archive_account_email
  parent_id = aws_organizations_organizational_unit.security.id
} 