locals {
  migration_container_image = var.migration_image_tag == null ? null : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:${var.migration_image_tag}"
}

resource "aws_ecs_task_definition" "migration" {
  count = var.enable_migration_task_definition ? 1 : 0

  family                   = "${local.name_prefix}-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "supportdesk-migration"
      image                  = local.migration_container_image
      essential              = true
      readonlyRootFilesystem = true
      user                   = "1001:1001"
      workingDirectory       = "/app"
      stopTimeout            = 30

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = [
        {
          name  = "PGDATABASE"
          value = var.database_name
        },
        {
          name  = "PGHOST"
          value = aws_db_instance.supportdesk.address
        },
        {
          name  = "PGPORT"
          value = tostring(var.database_port)
        },
        {
          name  = "PGSSLMODE"
          value = "require"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_APP_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:DATABASE_APP_PASSWORD::"
        },
        {
          name      = "DATABASE_URL"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:DATABASE_URL::"
        },
        {
          name      = "PGPASSWORD"
          valueFrom = "${aws_db_instance.supportdesk.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "PGUSER"
          valueFrom = "${aws_db_instance.supportdesk.master_user_secret[0].secret_arn}:username::"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.application.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "migration"
        }
      }
    }
  ])

  lifecycle {
    precondition {
      condition     = var.migration_image_tag != null
      error_message = "migration_image_tag must be set when enable_migration_task_definition is true."
    }
  }

  tags = {
    Name = "${local.name_prefix}-migration"
  }
}
