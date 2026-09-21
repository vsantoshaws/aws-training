# Copy this file to terraform.tfvars and adjust as needed.

aws_region   = "us-east-1"
project_name = "mall-support-agent"
mall_name    = "Metro Grand Mall"

# Lock this down to your IP for anything beyond a quick demo, e.g. ["203.0.113.4/32"]
allowed_chat_ui_cidrs = ["0.0.0.0/0"]

# Leave empty to manage the EC2 instance only via SSM Session Manager.
allowed_ssh_cidrs = ["0.0.0.0/0"]
ec2_key_pair_name = "chatbot-poc"

chat_ui_port      = 8000
ec2_instance_type = "t3.small"

embedding_model_id  = "amazon.titan-embed-text-v2:0"
embedding_dimension = 1024

bedrock_model_id = "us.anthropic.claude-sonnet-5"
