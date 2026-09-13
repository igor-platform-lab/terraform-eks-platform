# modules/eks_access/variables.tf

variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS."
}

variable "platform_admin_role_arn" {
  type        = string
  description = "ARN da IAM Role criada pelo IAM Identity Center Permission Set."
}