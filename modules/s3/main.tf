resource "aws_s3_bucket" "s3" {
  bucket = var.bucket
  region = var.region
}

resource "aws_s3_bucket_versioning" "s3_version" {
  bucket = aws_s3_bucket.s3.id

  versioning_configuration {
    status = var.status
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "crypy" {
  bucket = aws_s3_bucket.s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "SSE_KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "SSE_KMS" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.encryption_type == "SSE_KMS"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.s3.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}