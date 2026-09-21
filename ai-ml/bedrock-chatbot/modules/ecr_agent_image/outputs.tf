output "repository_url" {
  value = aws_ecr_repository.agent.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.agent.arn
}

output "image_uri" {
  value      = local.image_uri
  depends_on = [null_resource.build_and_push]
}
