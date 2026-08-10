variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "supportdesk"
}

variable "aws_region" {
  description = "AWS region where SupportDesk resources are created."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "SupportDesk is intentionally restricted to the Singapore region."
  }
}

variable "project_name" {
  description = "Name prefix used for SupportDesk resources."
  type        = string
  default     = "supportdesk"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "The project name must use lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["demo", "production"], var.environment)
    error_message = "The environment must be demo or production."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR assigned to the SupportDesk VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 2))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs, one for each Availability Zone."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition = length(var.public_subnet_cidrs) == 2 && alltrue([
      for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 1))
    ])
    error_message = "Exactly two valid public subnet CIDRs are required."
  }
}

variable "database_subnet_cidrs" {
  description = "Two private database subnet CIDRs, one for each Availability Zone."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]

  validation {
    condition = length(var.database_subnet_cidrs) == 2 && alltrue([
      for cidr in var.database_subnet_cidrs : can(cidrhost(cidr, 1))
    ])
    error_message = "Exactly two valid database subnet CIDRs are required."
  }
}

variable "app_port" {
  description = "TCP port exposed by the SupportDesk container."
  type        = number
  default     = 3000

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "The application port must be between 1 and 65535."
  }
}

variable "database_port" {
  description = "PostgreSQL TCP port."
  type        = number
  default     = 5432

  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "The database port must be between 1 and 65535."
  }
}

variable "database_name" {
  description = "Initial PostgreSQL database created for SupportDesk."
  type        = string
  default     = "supportdesk"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "The database name must start with a lowercase letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "database_master_username" {
  description = "PostgreSQL administrator used only for controlled database bootstrap and migrations."
  type        = string
  default     = "supportdesk_admin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_master_username)) && var.database_master_username != "postgres"
    error_message = "The master username must be a valid lowercase PostgreSQL identifier and cannot be postgres."
  }
}

variable "database_engine_version" {
  description = "PostgreSQL major version; RDS selects and maintains a compatible minor release."
  type        = string
  default     = "17"

  validation {
    condition     = contains(["16", "17"], var.database_engine_version)
    error_message = "The supported PostgreSQL major versions are 16 and 17."
  }
}

variable "database_instance_class" {
  description = "Cost-controlled Graviton RDS instance class used by the demo."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = contains(["db.t4g.micro", "db.t4g.small"], var.database_instance_class)
    error_message = "The demo database must use db.t4g.micro or db.t4g.small."
  }
}

variable "database_allocated_storage" {
  description = "Fixed gp3 storage allocation in GiB; automatic storage growth is disabled."
  type        = number
  default     = 20

  validation {
    condition     = var.database_allocated_storage >= 20 && var.database_allocated_storage <= 100
    error_message = "Database storage must be between 20 and 100 GiB."
  }
}

variable "database_backup_retention_days" {
  description = "Number of days RDS retains automated backups for point-in-time recovery."
  type        = number
  default     = 1

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 7
    error_message = "The demo backup retention period must be between 1 and 7 days."
  }
}

variable "database_deletion_protection" {
  description = "Prevents accidental database deletion; disable explicitly before an approved teardown."
  type        = bool
  default     = true
}

variable "database_skip_final_snapshot" {
  description = "Whether an approved teardown may omit the final database snapshot."
  type        = bool
  default     = false
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach the public HTTP listener during the demo."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = length(var.allowed_http_cidrs) > 0 && alltrue([
      for cidr in var.allowed_http_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "At least one valid IPv4 CIDR is required."
  }
}

variable "ecr_repository_name" {
  description = "Private ECR repository containing the SupportDesk image."
  type        = string
  default     = "supportdesk"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.ecr_repository_name))
    error_message = "The ECR repository name must be a valid private repository path."
  }
}

variable "container_image_tag" {
  description = "Immutable Git commit tag of the scanned SupportDesk image."
  type        = string
  default     = "984e1bc"

  validation {
    condition     = can(regex("^[0-9a-f]{7,40}$", var.container_image_tag))
    error_message = "The container image tag must be a 7-to-40-character lowercase Git commit SHA."
  }
}

variable "ecs_execution_role_name" {
  description = "Administrator-created role used by ECS to pull the image, inject secrets, and write logs."
  type        = string
  default     = "supportdesk-ecs-execution"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.ecs_execution_role_name))
    error_message = "The ECS execution role name must be a valid IAM role name."
  }
}

variable "ecs_task_role_name" {
  description = "Administrator-created least-privilege role assumed by the SupportDesk application task."
  type        = string
  default     = "supportdesk-ecs-task"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.ecs_task_role_name))
    error_message = "The ECS task role name must be a valid IAM role name."
  }
}

variable "fargate_cpu" {
  description = "Fargate task CPU units. The demo is intentionally fixed at 0.25 vCPU."
  type        = number
  default     = 256

  validation {
    condition     = var.fargate_cpu == 256
    error_message = "The cost-controlled demo task must use exactly 256 CPU units."
  }
}

variable "fargate_memory" {
  description = "Fargate task memory in MiB. The demo is intentionally fixed at 0.5 GB."
  type        = number
  default     = 512

  validation {
    condition     = var.fargate_memory == 512
    error_message = "The cost-controlled demo task must use exactly 512 MiB of memory."
  }
}

variable "application_log_retention_days" {
  description = "CloudWatch retention period for SupportDesk container logs."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14], var.application_log_retention_days)
    error_message = "The demo log retention period must be one of 1, 3, 5, 7, or 14 days."
  }
}

variable "enable_ecs_service" {
  description = "Starts the billable Fargate service only after runtime secrets and database migrations are ready."
  type        = bool
  default     = false
}
