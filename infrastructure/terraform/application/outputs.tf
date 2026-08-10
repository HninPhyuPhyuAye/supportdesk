output "availability_zones" {
  description = "Availability Zones used by the application network."
  value       = local.availability_zones
}

output "vpc_id" {
  description = "ID of the SupportDesk VPC."
  value       = aws_vpc.supportdesk.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the load balancer and demo Fargate tasks."
  value       = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
}

output "database_subnet_ids" {
  description = "Private subnet IDs reserved for the RDS DB subnet group."
  value       = [for key in sort(keys(aws_subnet.database)) : aws_subnet.database[key].id]
}

output "load_balancer_security_group_id" {
  description = "Security group attached to the Application Load Balancer."
  value       = aws_security_group.load_balancer.id
}

output "application_security_group_id" {
  description = "Security group attached to the SupportDesk Fargate task."
  value       = aws_security_group.application.id
}

output "database_security_group_id" {
  description = "Security group attached to the PostgreSQL database."
  value       = aws_security_group.database.id
}

output "database_address" {
  description = "Private DNS address of the SupportDesk PostgreSQL instance."
  value       = aws_db_instance.supportdesk.address
  sensitive   = true
}

output "database_master_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager master credential."
  value       = try(aws_db_instance.supportdesk.master_user_secret[0].secret_arn, null)
  sensitive   = true
}

output "application_url" {
  description = "Temporary HTTP URL of the SupportDesk Application Load Balancer."
  value       = local.application_base_url
}

output "application_secret_arn" {
  description = "ARN of the application runtime secret. The secret value is populated outside Terraform."
  value       = aws_secretsmanager_secret.application.arn
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the SupportDesk ECS cluster."
  value       = aws_ecs_cluster.supportdesk.name
}

output "ecs_service_enabled" {
  description = "Whether Terraform is configured to run the billable SupportDesk Fargate service."
  value       = var.enable_ecs_service
}

output "migration_task_definition_arn" {
  description = "ARN of the one-off database bootstrap task definition when enabled."
  value       = try(aws_ecs_task_definition.migration[0].arn, null)
}
