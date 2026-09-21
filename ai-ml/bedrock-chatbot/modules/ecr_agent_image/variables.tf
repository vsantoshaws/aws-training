variable "repository_name" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "build_context_path" {
  description = "Local path to the agent application's build context (containing the Dockerfile)."
  type        = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
