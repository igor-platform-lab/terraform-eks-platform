variable "state_bucket_name" {
  type        = string
  description = "Nome globalmente único do bucket de estado Terraform."
}

variable "github_role_name" {
  type        = string
  description = "Nome da role de deploy assumida pelo GitHub Actions."
  default     = "TerraformDeploy"
}

variable "github_subjects" {
  type        = set(string)
  description = "Subjects OIDC exatos autorizados, incluindo repositório e environment ou branch."
}

variable "github_policy_arns" {
  type        = set(string)
  description = "ARNs das policies gerenciadas anexadas à role. Permissões devem ser escolhidas explicitamente."
}
