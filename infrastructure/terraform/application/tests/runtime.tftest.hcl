mock_provider "aws" {
  override_data {
    override_during = plan
    target          = data.aws_availability_zones.available
    values = {
      names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    }
  }

  override_data {
    override_during = plan
    target          = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      user_id    = "AIDATESTONLY000000000"
    }
  }

  override_resource {
    target = aws_lb.supportdesk
    values = {
      arn      = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/supportdesk-demo-alb/1234567890abcdef"
      dns_name = "supportdesk-demo-alb-123.ap-southeast-1.elb.amazonaws.com"
    }
  }

  override_resource {
    target = aws_lb_target_group.application
    values = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/supportdesk-demo-app/1234567890abcdef"
    }
  }

  override_resource {
    target = aws_ecs_task_definition.supportdesk
    values = {
      arn = "arn:aws:ecs:ap-southeast-1:123456789012:task-definition/supportdesk-demo:1"
    }
  }

  override_resource {
    target = aws_db_instance.supportdesk
    values = {
      address = "supportdesk-demo-postgres.example.internal"
      master_user_secret = [
        {
          kms_key_id    = "arn:aws:kms:ap-southeast-1:123456789012:key/12345678-1234-1234-1234-123456789012"
          secret_arn    = "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:rds!db-test"
          secret_status = "active"
        }
      ]
    }
  }
}

run "disabled_cost_controlled_runtime" {
  command = apply

  assert {
    condition = one([
      for setting in aws_ecs_cluster.supportdesk.setting : setting.value
      if setting.name == "containerInsights"
    ]) == "disabled"
    error_message = "Paid ECS Container Insights must remain disabled for the demo."
  }

  assert {
    condition     = aws_cloudwatch_log_group.application.retention_in_days == 7
    error_message = "Application logs must expire after seven days."
  }

  assert {
    condition     = !aws_lb.supportdesk.internal && length(aws_lb.supportdesk.subnets) == 2
    error_message = "The load balancer must be internet-facing and span both public subnets."
  }

  assert {
    condition     = aws_lb_target_group.application.target_type == "ip" && aws_lb_target_group.application.health_check[0].path == "/api/health"
    error_message = "Fargate targets must use IP mode and the SupportDesk health endpoint."
  }

  assert {
    condition     = aws_ecs_task_definition.supportdesk.cpu == "256" && aws_ecs_task_definition.supportdesk.memory == "512"
    error_message = "The demo task must remain at 0.25 vCPU and 0.5 GB memory."
  }

  assert {
    condition     = aws_ecs_task_definition.supportdesk.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "The task must use the ARM64 runtime platform."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.supportdesk.container_definitions)[0].readonlyRootFilesystem
    error_message = "The SupportDesk container root filesystem must be read-only."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.supportdesk.container_definitions)[0].user == "1001:1001"
    error_message = "The SupportDesk container must run as its non-root image user."
  }

  assert {
    condition = sort([
      for secret in jsondecode(aws_ecs_task_definition.supportdesk.container_definitions)[0].secrets : secret.name
      ]) == sort([
      "BETTER_AUTH_GITHUB_CLIENT_ID",
      "BETTER_AUTH_GITHUB_CLIENT_SECRET",
      "BETTER_AUTH_SECRET",
      "DATABASE_URL",
    ])
    error_message = "All runtime credentials must be injected from Secrets Manager."
  }

  assert {
    condition     = length(aws_ecs_service.supportdesk) == 0
    error_message = "The billable Fargate service must remain disabled by default."
  }
}

run "explicitly_enabled_service_networking" {
  command = apply

  variables {
    enable_ecs_service = true
  }

  assert {
    condition     = length(aws_ecs_service.supportdesk) == 1 && aws_ecs_service.supportdesk[0].desired_count == 1
    error_message = "Explicit enablement must create exactly one demo task."
  }

  assert {
    condition     = aws_ecs_service.supportdesk[0].network_configuration[0].assign_public_ip
    error_message = "The no-NAT demo task requires an explicit public IP for outbound access."
  }

  assert {
    condition     = toset(aws_ecs_service.supportdesk[0].network_configuration[0].security_groups) == toset([aws_security_group.application.id])
    error_message = "The service must use only the restricted application security group."
  }

  assert {
    condition     = length(aws_ecs_service.supportdesk[0].network_configuration[0].subnets) == 2
    error_message = "The service must be able to place its single task in either public subnet."
  }
}

run "one_off_migration_task" {
  command = apply

  variables {
    enable_migration_task_definition = true
    migration_image_tag              = "migration-deadbee"
  }

  assert {
    condition     = length(aws_ecs_task_definition.migration) == 1
    error_message = "Explicit migration enablement must register exactly one task definition."
  }

  assert {
    condition     = aws_ecs_task_definition.migration[0].cpu == "256" && aws_ecs_task_definition.migration[0].memory == "512"
    error_message = "The migration task must use the smallest approved Fargate size."
  }

  assert {
    condition     = aws_ecs_task_definition.migration[0].runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "The migration task must use the ARM64 runtime platform."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migration[0].container_definitions)[0].readonlyRootFilesystem
    error_message = "The migration container root filesystem must be read-only."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migration[0].container_definitions)[0].user == "1001:1001"
    error_message = "The migration container must run as a non-root user."
  }

  assert {
    condition = sort([
      for secret in jsondecode(aws_ecs_task_definition.migration[0].container_definitions)[0].secrets : secret.name
      ]) == sort([
      "DATABASE_APP_PASSWORD",
      "DATABASE_URL",
      "PGPASSWORD",
      "PGUSER",
    ])
    error_message = "Migration credentials must be injected from the two approved Secrets Manager secrets."
  }
}
