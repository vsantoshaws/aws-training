variable "name" {
  description = "Name of the Bedrock Knowledge Base."
  type        = string
}

variable "embedding_model_id" {
  description = "Bedrock embedding foundation model id, e.g. amazon.titan-embed-text-v2:0."
  type        = string
}

variable "embedding_dimension" {
  description = "Embedding vector dimension (must match the OpenSearch vector index)."
  type        = number
}

variable "aws_region" {
  description = "AWS region, used to build the embedding model ARN."
  type        = string
}

variable "collection_arn" {
  description = "ARN of the OpenSearch Serverless collection backing this knowledge base."
  type        = string
}

variable "vector_index_name" {
  type = string
}

variable "vector_field_name" {
  type = string
}

variable "text_field_name" {
  type = string
}

variable "metadata_field_name" {
  type = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket containing the source documents for the data source."
  type        = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_inclusion_prefix" {
  description = "Only ingest objects under this S3 key prefix."
  type        = string
  default     = "policies/"
}

variable "chunking_max_tokens" {
  description = "Maximum tokens per chunk."
  type        = number
  default     = 400
}

variable "chunking_overlap_percentage" {
  description = "Percentage overlap between consecutive chunks."
  type        = number
  default     = 20
}

# Bumping this value (e.g. to a hash of the uploaded documents) forces a new
# ingestion job to run so freshly uploaded/changed S3 documents get indexed.
variable "ingestion_trigger" {
  description = "Opaque value that changes whenever the source documents change, used to trigger a re-sync."
  type        = string
}

variable "tags" {
  description = "Common tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
