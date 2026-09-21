data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
  })

  # S3 bucket names must be globally unique; suffix with the account id.
  kb_bucket_name  = "${var.project_name}-kb-docs-${data.aws_caller_identity.current.account_id}"
  collection_name = substr(replace("${var.project_name}-vs", "_", "-"), 0, 32)
  kb_name         = "${var.project_name}-kb"
  ecr_repo_name   = "${var.project_name}-agent"
  runtime_name    = replace("${var.project_name}_runtime", "-", "_")

  agent_app_path = "${path.module}/agent_app"
  web_ui_app_py  = "${path.module}/web_ui/app.py"
  sample_data    = "${path.module}/sample_data"
}

# ---------------------------------------------------------------------------
# 1. Networking (VPC + public subnets + security group for the chat UI EC2)
# ---------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  chat_ui_port          = var.chat_ui_port
  allowed_chat_ui_cidrs = var.allowed_chat_ui_cidrs
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  tags                  = local.common_tags
}

# ---------------------------------------------------------------------------
# 2. S3 bucket for knowledge base source documents + sample policy docs
# ---------------------------------------------------------------------------
module "knowledge_source" {
  source = "./modules/s3_knowledge_source"

  bucket_name     = local.kb_bucket_name
  source_data_dir = local.sample_data
  tags            = local.common_tags
}

# ---------------------------------------------------------------------------
# 3. OpenSearch Serverless vector store backing the knowledge base
# ---------------------------------------------------------------------------
module "opensearch_vectorstore" {
  source = "./modules/opensearch_vectorstore"

  collection_name  = local.collection_name
  vector_dimension = var.embedding_dimension

  # Access is granted to (a) the Terraform caller, wired in automatically by
  # the module, and (b) the Bedrock Knowledge Base execution role below.
  additional_data_access_principal_arns = [module.bedrock_knowledge_base.role_arn]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# 4. Bedrock Knowledge Base (VECTOR type) with an S3 data source
# ---------------------------------------------------------------------------
module "bedrock_knowledge_base" {
  source = "./modules/bedrock_knowledge_base"

  name                = local.kb_name
  aws_region          = var.aws_region
  embedding_model_id  = var.embedding_model_id
  embedding_dimension = var.embedding_dimension

  collection_arn      = module.opensearch_vectorstore.collection_arn
  vector_index_name   = module.opensearch_vectorstore.vector_index_name
  vector_field_name   = module.opensearch_vectorstore.vector_field_name
  text_field_name     = module.opensearch_vectorstore.text_field_name
  metadata_field_name = module.opensearch_vectorstore.metadata_field_name

  s3_bucket_arn       = module.knowledge_source.bucket_arn
  s3_bucket_name      = module.knowledge_source.bucket_name
  s3_inclusion_prefix = "policies/"

  ingestion_trigger = module.knowledge_source.documents_fingerprint

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# 5. Build the Strands agent container image and push it to ECR
# ---------------------------------------------------------------------------
module "ecr_agent_image" {
  source = "./modules/ecr_agent_image"

  repository_name    = local.ecr_repo_name
  build_context_path = local.agent_app_path
  aws_region         = var.aws_region
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# 6. Bedrock AgentCore Runtime running the Strands agent container
# ---------------------------------------------------------------------------
module "agentcore_runtime" {
  source = "./modules/agentcore_runtime"

  agent_runtime_name  = local.runtime_name
  container_image_uri = module.ecr_agent_image.image_uri
  ecr_repository_arn  = module.ecr_agent_image.repository_arn

  knowledge_base_id  = module.bedrock_knowledge_base.knowledge_base_id
  knowledge_base_arn = module.bedrock_knowledge_base.knowledge_base_arn

  bedrock_model_id = var.bedrock_model_id
  aws_region       = var.aws_region

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# 7. EC2 instance hosting the chat UI, which calls the AgentCore runtime
# ---------------------------------------------------------------------------
module "ec2_chat_ui" {
  source = "./modules/ec2_chat_ui"

  project_name         = var.project_name
  vpc_id               = module.networking.vpc_id
  subnet_id            = module.networking.public_subnet_ids[0]
  security_group_id    = module.networking.chat_ui_security_group_id
  instance_type        = var.ec2_instance_type
  chat_ui_port         = var.chat_ui_port
  aws_region           = var.aws_region
  agent_runtime_arn    = module.agentcore_runtime.agent_runtime_arn
  chat_app_source_path = local.web_ui_app_py
  key_pair_name        = var.ec2_key_pair_name
  mall_name            = var.mall_name

  tags = local.common_tags
}
