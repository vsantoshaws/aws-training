data "aws_caller_identity" "current" {}

locals {
  embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
}

# ---------------------------------------------------------------------------
# IAM role assumed by the Bedrock Knowledge Base service to read S3 source
# documents, call the embedding model, and read/write the vector index.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "kb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "kb" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "kb_permissions" {
  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.embedding_model_arn]
  }

  statement {
    sid       = "OpenSearchServerlessAccess"
    effect    = "Allow"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.collection_arn]
  }

  statement {
    sid    = "S3SourceDocuments"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "kb" {
  name   = "${var.name}-permissions"
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_permissions.json
}

# ---------------------------------------------------------------------------
# Knowledge Base + S3 data source
# ---------------------------------------------------------------------------
resource "aws_bedrockagent_knowledge_base" "this" {
  name     = var.name
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimension
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.collection_arn
      vector_index_name = var.vector_index_name
      field_mapping {
        vector_field   = var.vector_field_name
        text_field     = var.text_field_name
        metadata_field = var.metadata_field_name
      }
    }
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy.kb]
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "${var.name}-s3-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = var.s3_bucket_arn
      inclusion_prefixes = [var.s3_inclusion_prefix]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = var.chunking_max_tokens
        overlap_percentage = var.chunking_overlap_percentage
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Ingestion job: (re)syncs the S3 data source into the vector index whenever
# the uploaded documents change. Runs via the AWS CLI because Terraform has
# no native resource for triggering/tracking a Bedrock ingestion job.
# ---------------------------------------------------------------------------
resource "null_resource" "start_ingestion" {
  triggers = {
    data_source_id    = aws_bedrockagent_data_source.s3.data_source_id
    ingestion_trigger = var.ingestion_trigger
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      echo "Starting ingestion job for knowledge base ${aws_bedrockagent_knowledge_base.this.id} / data source ${aws_bedrockagent_data_source.s3.data_source_id}"
      JOB_ID=$(aws bedrock-agent start-ingestion-job \
        --knowledge-base-id "${aws_bedrockagent_knowledge_base.this.id}" \
        --data-source-id "${aws_bedrockagent_data_source.s3.data_source_id}" \
        --region "${var.aws_region}" \
        --query 'ingestionJob.ingestionJobId' --output text)
      echo "Ingestion job started: $JOB_ID"

      for i in $(seq 1 30); do
        STATUS=$(aws bedrock-agent get-ingestion-job \
          --knowledge-base-id "${aws_bedrockagent_knowledge_base.this.id}" \
          --data-source-id "${aws_bedrockagent_data_source.s3.data_source_id}" \
          --ingestion-job-id "$JOB_ID" \
          --region "${var.aws_region}" \
          --query 'ingestionJob.status' --output text)
        echo "Ingestion job status: $STATUS"
        if [ "$STATUS" = "COMPLETE" ]; then
          exit 0
        fi
        if [ "$STATUS" = "FAILED" ]; then
          echo "Ingestion job failed" >&2
          exit 1
        fi
        sleep 10
      done
      echo "Timed out waiting for ingestion job to complete (it may still finish in the background)."
    EOT
  }

  depends_on = [aws_bedrockagent_data_source.s3]
}
