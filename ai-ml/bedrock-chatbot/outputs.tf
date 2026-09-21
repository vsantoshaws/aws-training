output "chat_ui_url" {
  description = "Open this URL in a browser to chat with the Metro Grand Mall support agent."
  value       = module.ec2_chat_ui.chat_url
}

output "chat_ui_public_ip" {
  value = module.ec2_chat_ui.public_ip
}

output "agent_runtime_arn" {
  value = module.agentcore_runtime.agent_runtime_arn
}

output "knowledge_base_id" {
  value = module.bedrock_knowledge_base.knowledge_base_id
}

output "ecr_repository_url" {
  value = module.ecr_agent_image.repository_url
}

output "kb_documents_bucket" {
  value = module.knowledge_source.bucket_name
}

output "opensearch_collection_endpoint" {
  value = module.opensearch_vectorstore.collection_endpoint
}
