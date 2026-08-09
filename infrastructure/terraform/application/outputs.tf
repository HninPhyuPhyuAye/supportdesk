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
