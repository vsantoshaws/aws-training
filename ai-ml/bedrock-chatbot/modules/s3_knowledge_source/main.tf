resource "aws_s3_bucket" "kb_docs" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Upload every file found in the local source_data_dir as a knowledge base document.
resource "aws_s3_object" "kb_documents" {
  for_each = fileset(var.source_data_dir, "**")

  bucket       = aws_s3_bucket.kb_docs.id
  key          = "policies/${each.value}"
  source       = "${var.source_data_dir}/${each.value}"
  etag         = filemd5("${var.source_data_dir}/${each.value}")
  content_type = "text/plain"

  tags = var.tags
}
