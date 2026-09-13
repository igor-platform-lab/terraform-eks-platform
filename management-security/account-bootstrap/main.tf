module "account_baseline" {
  source = "../../modules/account_baseline"

  state_bucket_name  = var.state_bucket_name
  github_role_name   = var.github_role_name
  github_subjects    = var.github_subjects
  github_policy_arns = var.github_policy_arns
}
