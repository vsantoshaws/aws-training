variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "chat_ui_port" {
  type = number
}

variable "aws_region" {
  type = string
}

variable "agent_runtime_arn" {
  type = string
}

variable "chat_app_source_path" {
  description = "Local path to the Flask chat UI application file (app.py)."
  type        = string
}

variable "key_pair_name" {
  description = "Optional EC2 key pair name for SSH access. Leave null to rely on SSM Session Manager only."
  type        = string
  default     = null
}

variable "mall_name" {
  description = "Display name shown in the chat UI header."
  type        = string
  default     = "Metro Grand Mall"
}

variable "tags" {
  type    = map(string)
  default = {}
}
