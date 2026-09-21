data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Execution role assumed by the Bedrock AgentCore Runtime service to pull the
# container image and, from inside the running agent, call Bedrock models,
# retrieve from the Knowledge Base, and emit logs/traces.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "runtime" {
  name               = "${var.agent_runtime_name}-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "runtime_permissions" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPullImage"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "InvokeChatModel"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      # Cross-region inference profiles (e.g. "us.anthropic...") fan requests
      # out to whichever underlying region has capacity, so the foundation-
      # model grant must span all regions the profile can route to, not just
      # var.aws_region.
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  statement {
    sid    = "QueryKnowledgeBase"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate",
      "bedrock:GetKnowledgeBase",
    ]
    resources = [var.knowledge_base_arn]
  }

  statement {
    sid    = "Logging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid    = "Tracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "runtime" {
  name   = "${var.agent_runtime_name}-runtime-permissions"
  role   = aws_iam_role.runtime.id
  policy = data.aws_iam_policy_document.runtime_permissions.json
}

# ---------------------------------------------------------------------------
# The AgentCore Runtime itself, running our Strands agent container.
# ---------------------------------------------------------------------------
resource "aws_bedrockagentcore_agent_runtime" "agent" {
  agent_runtime_name = var.agent_runtime_name
  description        = "Strands agent backed by a Bedrock Knowledge Base of shopping mall customer support policies."
  role_arn           = aws_iam_role.runtime.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_image_uri
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }

  environment_variables = {
    KNOWLEDGE_BASE_ID = var.knowledge_base_id
    BEDROCK_MODEL_ID  = var.bedrock_model_id
    AWS_REGION_NAME   = var.aws_region
    LOG_LEVEL         = "INFO"
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy.runtime]
}
