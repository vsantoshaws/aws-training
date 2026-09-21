variable "project_name" {
  description = "Name prefix used for all networking resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "chat_ui_port" {
  description = "TCP port the chat UI listens on and that must be reachable from the internet."
  type        = number
}

variable "allowed_chat_ui_cidrs" {
  description = "CIDR blocks allowed to reach the chat UI port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the chat UI EC2 instance. Leave empty to disable SSH ingress entirely."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
