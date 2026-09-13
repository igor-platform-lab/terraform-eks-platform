locals {
  blueprint_file    = "${path.module}/templates/account-baseline.yaml"
  blueprint_version = "v-${substr(filesha256(local.blueprint_file), 0, 12)}"
}

module "blueprints_bucket" {
  source = "../modules/s3"

  region          = var.aws_region
  bucket          = "controltower-blueprints-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  status          = "Enabled"
  encryption_type = "SSE_S3"
}

resource "aws_s3_object" "account_baseline" {
  bucket       = module.blueprints_bucket.bucket_id
  key          = "account-baseline/${local.blueprint_version}.yaml"
  source       = local.blueprint_file
  source_hash  = filesha256(local.blueprint_file)
  content_type = "application/yaml"
}

resource "aws_servicecatalog_product" "account_baseline" {
  name        = "account-baseline"
  owner       = "Management"
  description = "Bucket de estado, GitHub OIDC e role de deploy para novas contas."
  type        = "CLOUD_FORMATION_TEMPLATE"

  provisioning_artifact_parameters {
    name         = local.blueprint_version
    type         = "CLOUD_FORMATION_TEMPLATE"
    template_url = "https://${module.blueprints_bucket.bucket_id}.s3.${var.aws_region}.${data.aws_partition.current.dns_suffix}/${aws_s3_object.account_baseline.key}"
  }
}

resource "aws_iam_role" "blueprint_access" {
  name = "AWSControlTowerBlueprintAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSControlTowerAdmin",
          var.control_tower_operator_arn
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "blueprint_servicecatalog" {
  role       = aws_iam_role.blueprint_access.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSServiceCatalogAdminFullAccess"
}

resource "aws_iam_role_policy_attachment" "blueprint_s3" {
  role       = aws_iam_role.blueprint_access.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
