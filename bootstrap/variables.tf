variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "state_bucket_name" {
  type = string
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to assume the Terraform role, in owner/repository format."
}

variable "github_branch" {
  type        = string
  description = "GitHub branch allowed to assume the Terraform role."
  default     = "main"
}

variable "localstack_enabled" {
  type    = bool
  default = false
}

variable "localstack_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "audit_account_email" {
  type = string
}

variable "log_archive_account_email" {
  type = string
}