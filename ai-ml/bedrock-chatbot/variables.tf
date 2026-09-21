variable "aws_region" {
  description = "AWS region to deploy into. Must be a region where Bedrock AgentCore, Bedrock Knowledge Bases, and OpenSearch Serverless are all available (e.g. us-east-1, us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resources (letters, numbers, hyphens)."
  type        = string
  default     = "mall-support-agent"
}

variable "mall_name" {
  description = "Display name of the shopping mall, shown in the chat UI and used in generated docs."
  type        = string
  default     = "Metro Grand Mall"
}

# --- Networking -------------------------------------------------------------

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "allowed_chat_ui_cidrs" {
  description = "CIDR blocks allowed to reach the chat UI. Defaults to open internet; restrict this for anything beyond a quick demo."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the EC2 instance. Empty by default (use SSM Session Manager instead)."
  type        = list(string)
  default     = []
}

variable "ec2_key_pair_name" {
  description = "Optional existing EC2 key pair name for SSH access to the chat UI instance."
  type        = string
  default     = null
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "chat_ui_port" {
  description = "Port the chat UI listens on and that you will browse to (http://<ec2-ip>:<port>)."
  type        = number
  default     = 8000
}

# --- Knowledge base / vector store -------------------------------------------

variable "embedding_model_id" {
  description = "Bedrock embedding model id."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimension" {
  description = "Embedding vector dimension. Must match the embedding model (1024 for amazon.titan-embed-text-v2:0)."
  type        = number
  default     = 1024
}

# --- Agent / model ------------------------------------------------------------

variable "bedrock_model_id" {
  description = "Bedrock chat model id (or cross-region inference profile id) the Strands agent uses to generate answers."
  type        = string
  default     = "us.anthropic.claude-sonnet-5"
}

variable "tags" {
  description = "Extra tags merged into every resource's default tags."
  type        = map(string)
  default     = {}
}
