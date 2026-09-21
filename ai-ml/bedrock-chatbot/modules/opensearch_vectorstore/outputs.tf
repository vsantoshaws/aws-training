output "collection_arn" {
  value = aws_opensearchserverless_collection.kb.arn
}

output "collection_id" {
  value = aws_opensearchserverless_collection.kb.id
}

output "collection_endpoint" {
  value = aws_opensearchserverless_collection.kb.collection_endpoint
}

output "vector_index_name" {
  value = opensearch_index.vector_index.name
}

output "vector_field_name" {
  value = var.vector_field_name
}

output "text_field_name" {
  value = var.text_field_name
}

output "metadata_field_name" {
  value = var.metadata_field_name
}
