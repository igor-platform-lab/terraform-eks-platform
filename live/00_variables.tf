variable "environment_tags" {
  type        = map(string)
  description = "Tags specific to the environment."
  default     = {}

}

variable "aws_region" {
  type        = string
  description = "AWS region where the workload is deployed."
}

variable "aws_profile" {
  type        = string
  description = "Local AWS CLI profile used for Terraform."
  default     = null
}

variable "localstack_enabled" {
  type        = bool
  description = "Use LocalStack endpoints instead of AWS endpoints."
  default     = false
}

variable "localstack_endpoint" {
  type        = string
  description = "LocalStack edge endpoint."
  default     = "http://localhost:4566"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}
