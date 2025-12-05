output "repository_urls" {
  value = { for k, v in aws_ecr_repository.sentinel_service : k => v.repository_url }
}

output "repository_arns" {
  value = { for k, v in aws_ecr_repository.sentinel_service : k => v.arn }
}
