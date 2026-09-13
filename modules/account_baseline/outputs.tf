output "state_bucket_name" {
  value       = module.terraform_state.bucket_id
  description = "Nome do bucket para configurar os backends."
}

output "state_bucket_arn" {
  value       = module.terraform_state.bucket_arn
  description = "ARN do bucket de estado."
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN do provider OIDC do GitHub nesta conta."
}

output "github_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN a configurar em AWS_ROLE_ARN no GitHub Environment."
}
