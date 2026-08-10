data "aws_caller_identity" "current" {}

locals {
  container_image       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:${var.container_image_tag}"
  execution_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_execution_role_name}"
  task_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_task_role_name}"
  application_base_url  = "http://${aws_lb.supportdesk.dns_name}"
  application_log_group = "/ecs/${local.name_prefix}"
}

resource "aws_ecs_cluster" "supportdesk" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = local.name_prefix
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = local.application_log_group
  retention_in_days = var.application_log_retention_days

  tags = {
    Name = "${local.name_prefix}-application"
  }
}

resource "aws_secretsmanager_secret" "application" {
  name                    = "${var.project_name}/${var.environment}/application"
  description             = "Runtime configuration for the SupportDesk ECS task. Values are populated outside Terraform."
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-application"
  }
}

resource "aws_lb" "supportdesk" {
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.load_balancer.id]
  subnets                    = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  idle_timeout               = 60

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "application" {
  name                 = "${local.name_prefix}-app"
  port                 = var.app_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.supportdesk.id
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.name_prefix}-app"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.supportdesk.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }

  tags = {
    Name = "${local.name_prefix}-http"
  }
}

resource "aws_ecs_task_definition" "supportdesk" {
  family                   = local.name_prefix
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
    name = "next-cache"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "supportdesk"
      image                  = local.container_image
      essential              = true
      readonlyRootFilesystem = true
      user                   = "1001:1001"
      workingDirectory       = "/app"
      stopTimeout            = 30

      linuxParameters = {
        initProcessEnabled = true
      }

      portMappings = [
        {
          name          = "supportdesk-http"
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "BETTER_AUTH_URL"
          value = local.application_base_url
        },
        {
          name  = "HOSTNAME"
          value = "0.0.0.0"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.app_port)
        }
      ]

      secrets = [
        {
          name      = "BETTER_AUTH_GITHUB_CLIENT_ID"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:BETTER_AUTH_GITHUB_CLIENT_ID::"
        },
        {
          name      = "BETTER_AUTH_GITHUB_CLIENT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:BETTER_AUTH_GITHUB_CLIENT_SECRET::"
        },
        {
          name      = "BETTER_AUTH_SECRET"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:BETTER_AUTH_SECRET::"
        },
        {
          name      = "DATABASE_URL"
          valueFrom = "${aws_secretsmanager_secret.application.arn}:DATABASE_URL::"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "next-cache"
          containerPath = "/app/.next/cache"
          readOnly      = false
        },
        {
          sourceVolume  = "tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"fetch('http://127.0.0.1:${var.app_port}/api/health').then((response) => { if (!response.ok) process.exit(1) }).catch(() => process.exit(1))\"",
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.application.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "supportdesk"
        }
      }
    }
  ])

  tags = {
    Name = local.name_prefix
  }
}

resource "aws_ecs_service" "supportdesk" {
  count = var.enable_ecs_service ? 1 : 0

  name                               = local.name_prefix
  cluster                            = aws_ecs_cluster.supportdesk.id
  task_definition                    = aws_ecs_task_definition.supportdesk.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.application.arn
    container_name   = "supportdesk"
    container_port   = var.app_port
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.application.id]
    subnets          = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = local.name_prefix
  }
}
