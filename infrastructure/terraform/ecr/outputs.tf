output "repository_name" {
  description = "Name of the SupportDesk ECR repository."
  value       = aws_ecr_repository.supportdesk.name
}

output "repository_url" {
  description = "Docker registry URL used when tagging and pushing the image."
  value       = aws_ecr_repository.supportdesk.repository_url
}
