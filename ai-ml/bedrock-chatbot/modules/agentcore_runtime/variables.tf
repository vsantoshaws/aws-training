variable "agent_runtime_name" {
  description = "Name of the Bedrock AgentCore Runtime (letters, numbers, underscores only)."
  type        = string
}

variable "container_image_uri" {
  description = "ECR image URI (with tag) to run as the agent runtime."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository holding the agent image, for scoped pull permissions."
  type        = string
}

variable "knowledge_base_id" {
  type = string
}

variable "knowledge_base_arn" {
  type = string
}

variable "bedrock_model_id" {
  description = "Bedrock model id or cross-region inference profile id used by the Strands agent, e.g. us.anthropic.claude-3-5-sonnet-20241022-v2:0."
  type        = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
