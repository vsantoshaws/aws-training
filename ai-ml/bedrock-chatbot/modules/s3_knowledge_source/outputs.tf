output "bucket_name" {
  value = aws_s3_bucket.kb_docs.id
}

output "bucket_arn" {
  value = aws_s3_bucket.kb_docs.arn
}

output "uploaded_object_keys" {
  value = [for o in aws_s3_object.kb_documents : o.key]
}

# Changes whenever any uploaded document's content changes; used to trigger a
# re-sync (ingestion job) of the Bedrock Knowledge Base data source.
output "documents_fingerprint" {
  value = md5(join(",", [for o in aws_s3_object.kb_documents : o.etag]))
}
