variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection (lowercase letters, numbers, hyphens; max 32 chars)."
  type        = string
}

variable "vector_index_name" {
  description = "Name of the vector index created inside the collection."
  type        = string
  default     = "bedrock-knowledge-base-default-index"
}

variable "vector_field_name" {
  description = "Name of the knn_vector field used by the Bedrock Knowledge Base."
  type        = string
  default     = "bedrock-knowledge-base-default-vector"
}

variable "text_field_name" {
  description = "Name of the field that stores the raw text chunk."
  type        = string
  default     = "AMAZON_BEDROCK_TEXT_CHUNK"
}

variable "metadata_field_name" {
  description = "Name of the field that stores chunk metadata."
  type        = string
  default     = "AMAZON_BEDROCK_METADATA"
}

variable "vector_dimension" {
  description = "Dimensionality of the embedding vectors (must match the embedding model, e.g. 1024 for amazon.titan-embed-text-v2:0)."
  type        = number
  default     = 1024
}

variable "additional_data_access_principal_arns" {
  description = "Extra IAM principal ARNs (in addition to the Terraform caller) granted read/write access to the collection and its indexes, e.g. the Bedrock Knowledge Base execution role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
