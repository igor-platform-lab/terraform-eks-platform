variable "aws_region" {
  type        = string
  description = "Home Region do Control Tower."
  default     = "us-east-2"
}

variable "aws_profile" {
  type        = string
  description = "Profile da management account."
  default     = null
}

variable "environment" {
  type    = string
  default = "management-security"
}

variable "environment_tags" {
  type    = map(string)
  default = {}
}

variable "control_tower_operator_arn" {
  type        = string
  description = "ARN IAM da role ou usuário que acessa o Account Factory pelo console. Não use ARN de sessão STS."
}
