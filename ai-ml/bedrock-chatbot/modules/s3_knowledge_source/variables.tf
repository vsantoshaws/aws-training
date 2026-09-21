variable "bucket_name" {
  description = "Globally-unique name for the S3 bucket that stores the knowledge base source documents."
  type        = string
}

variable "source_data_dir" {
  description = "Local directory whose files are uploaded as knowledge base source documents."
  type        = string
}

variable "tags" {
  description = "Common tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
