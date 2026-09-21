resource "aws_ecr_repository" "agent" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "agent" {
  repository = aws_ecr_repository.agent.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

locals {
  build_files_hash = md5(join("", [
    for f in fileset(var.build_context_path, "**") : filemd5("${var.build_context_path}/${f}")
  ]))
  image_uri = "${aws_ecr_repository.agent.repository_url}:${var.image_tag}"
}

# Builds the agent container for linux/arm64 (required by Bedrock AgentCore
# Runtime) and pushes it to ECR. Re-runs automatically whenever any file
# under build_context_path changes. Requires Docker (with buildx) on the
# machine running `terraform apply`.
resource "null_resource" "build_and_push" {
  triggers = {
    build_files_hash = local.build_files_hash
    repository_url   = aws_ecr_repository.agent.repository_url
    image_tag        = var.image_tag
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      echo "Logging in to ECR ${aws_ecr_repository.agent.repository_url}"
      aws ecr get-login-password --region "${var.aws_region}" \
        | docker login --username AWS --password-stdin "${aws_ecr_repository.agent.repository_url}"

      docker buildx inspect agentcore-builder >/dev/null 2>&1 \
        || docker buildx create --name agentcore-builder --use
      docker buildx use agentcore-builder

      echo "Building and pushing ${local.image_uri} (linux/arm64)"
      docker buildx build \
        --platform linux/arm64 \
        -t "${local.image_uri}" \
        --push \
        "${var.build_context_path}"
    EOT
  }

  depends_on = [aws_ecr_repository.agent]
}
