output "state_bucket_name" {
  value       = module.account_baseline.state_bucket_name
  description = "Bucket para os arquivos de backend."
}

output "github_role_arn" {
  value       = module.account_baseline.github_role_arn
  description = "Valor de AWS_ROLE_ARN no GitHub Environment desta conta."
}

output "github_oidc_provider_arn" {
  value       = module.account_baseline.github_oidc_provider_arn
  description = "Provider OIDC criado nesta conta."
}
