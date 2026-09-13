variable "bucket" {
  type        = string
  description = "Name of the bucket, which must be globally unique within the AWS partition."

}

variable "region" {
  type        = string
  description = "Region of the bucket"

}

variable "status" {
  type        = string
  description = "Versioning status: Enabled or Suspended."

  validation {
    condition     = contains(["Enabled", "Suspended"], var.status)
    error_message = "status must be Enabled or Suspended."
  }

}

variable "block_public_acls" {
  type    = bool
  default = true

}

variable "block_public_policy" {
  type    = bool
  default = true
}

variable "ignore_public_acls" {
  type    = bool
  default = true

}

variable "restrict_public_buckets" {
  type    = bool
  default = true

}

variable "encryption_type" {
  type        = string
  description = "Type of CRYPT : SSE_S3 or SSE_KMS"
  default     = "SSE_S3"

  validation {
    condition     = contains(["SSE_S3", "SSE_KMS"], var.encryption_type)
    error_message = "Use SSE_S3 or SSE_KMS."
  }

}

variable "kms_key_arn" {
  type        = string
  description = "Key if the encrypt is SSE_KMS"
  default     = null

  validation {
    condition     = var.encryption_type != "SSE_KMS" || var.kms_key_arn != null
    error_message = "kms_key_arn is necessary."
  }

}