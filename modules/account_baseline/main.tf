data "aws_region" "current" {}

module "terraform_state" {
  source = "../s3"

  region          = data.aws_region.current.region
  bucket          = var.state_bucket_name
  status          = "Enabled"
  encryption_type = "SSE_S3"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_actions" {
  name = var.github_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = sort(tolist(var.github_subjects))
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = var.github_policy_arns

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
