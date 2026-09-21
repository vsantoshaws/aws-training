data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# IAM role: lets the EC2 instance invoke the AgentCore runtime and (optionally)
# be managed via SSM Session Manager instead of SSH.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chat_ui" {
  name               = "${var.project_name}-chat-ui-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.chat_ui.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "invoke_agent" {
  statement {
    sid    = "InvokeAgentRuntime"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
    ]
    resources = [
      var.agent_runtime_arn,
      "${var.agent_runtime_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "invoke_agent" {
  name   = "${var.project_name}-invoke-agent-runtime"
  role   = aws_iam_role.chat_ui.id
  policy = data.aws_iam_policy_document.invoke_agent.json
}

resource "aws_iam_instance_profile" "chat_ui" {
  name = "${var.project_name}-chat-ui-profile"
  role = aws_iam_role.chat_ui.name
}

# ---------------------------------------------------------------------------
# EC2 instance running the chat UI
# ---------------------------------------------------------------------------
locals {
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_py_base64     = base64encode(file(var.chat_app_source_path))
    aws_region        = var.aws_region
    agent_runtime_arn = var.agent_runtime_arn
    chat_ui_port      = var.chat_ui_port
    mall_name         = var.mall_name
  })
}

resource "aws_instance" "chat_ui" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.chat_ui.name
  key_name                    = var.key_pair_name
  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # enforce IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name       = "${var.project_name}-chat-ui"
    work-hours = "full-time"
    Email      = "svasantala@evoketechnologies.com"
    Owner      = "SantoshKumarVasantala"
  })
}
