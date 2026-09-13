output "blueprint_hub_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "ID da management account a informar como hub no Account Factory."
}

output "blueprint_product_id" {
  value       = aws_servicecatalog_product.account_baseline.id
  description = "Produto account-baseline publicado no Service Catalog."
}

output "blueprint_version" {
  value       = local.blueprint_version
  description = "Versão a selecionar no Account Factory."
}

output "blueprint_access_role_arn" {
  value       = aws_iam_role.blueprint_access.arn
  description = "Role usada pelo Control Tower para acessar o blueprint."
}
