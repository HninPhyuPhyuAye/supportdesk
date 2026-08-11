locals {
  monitoring_enabled = var.enable_monitoring_alarms && var.enable_ecs_service
  monitoring_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "SupportDesk"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = local.monitoring_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-unhealthy-targets"
  alarm_description   = "At least one SupportDesk ALB target remained unhealthy for two minutes."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.supportdesk.arn_suffix
    TargetGroup  = aws_lb_target_group.application.arn_suffix
  }

  tags = merge(local.monitoring_tags, {
    Component = "load-balancer"
    Name      = "${local.name_prefix}-alb-unhealthy-targets"
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  count = local.monitoring_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-high-cpu"
  alarm_description   = "SupportDesk ECS service CPU utilization remained above 80 percent for five minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.supportdesk.name
    ServiceName = aws_ecs_service.supportdesk[0].name
  }

  tags = merge(local.monitoring_tags, {
    Component = "application"
    Name      = "${local.name_prefix}-ecs-high-cpu"
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  count = local.monitoring_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-high-memory"
  alarm_description   = "SupportDesk ECS service memory utilization remained above 80 percent for five minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.supportdesk.name
    ServiceName = aws_ecs_service.supportdesk[0].name
  }

  tags = merge(local.monitoring_tags, {
    Component = "application"
    Name      = "${local.name_prefix}-ecs-high-memory"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  count = local.monitoring_enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-low-free-storage"
  alarm_description   = "SupportDesk RDS free storage remained below 2 GiB for fifteen minutes."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 2 * 1024 * 1024 * 1024
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.supportdesk.identifier
  }

  tags = merge(local.monitoring_tags, {
    Component = "database"
    Name      = "${local.name_prefix}-rds-low-free-storage"
  })
}
