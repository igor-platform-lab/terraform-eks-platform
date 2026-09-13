variable "aws_region" {
  type        = string
  description = "Região do bucket e do provider AWS."
  default     = "us-east-2"
}

variable "aws_profile" {
  type        = string
  description = "Profile local da conta de destino. Null usa a cadeia padrão de credenciais."
  default     = null
}

variable "environment" {
  type        = string
  description = "Identificação do ambiente nas tags, por exemplo dev ou prod."
}

variable "state_bucket_name" {
  type        = string
  description = "Nome globalmente único do bucket de estado desta conta."
}

variable "github_role_name" {
  type        = string
  description = "Nome da role de deploy do GitHub Actions."
  default     = "TerraformDeploy"
}

variable "github_subjects" {
  type        = set(string)
  description = "Subjects OIDC exatos aceitos pela role."
}

variable "github_policy_arns" {
  type        = set(string)
  description = "Policies gerenciadas concedidas explicitamente à role de deploy."
}
