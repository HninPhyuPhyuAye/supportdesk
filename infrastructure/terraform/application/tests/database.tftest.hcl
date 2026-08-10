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
}

run "cost_controlled_private_database" {
  command = apply

  assert {
    condition     = aws_db_instance.supportdesk.engine == "postgres" && aws_db_instance.supportdesk.engine_version == "17"
    error_message = "The demo database must use the approved PostgreSQL major version."
  }

  assert {
    condition     = aws_db_instance.supportdesk.instance_class == "db.t4g.micro" && aws_db_instance.supportdesk.allocated_storage == 20
    error_message = "The demo database must use the cost-controlled instance and storage defaults."
  }

  assert {
    condition     = aws_db_instance.supportdesk.max_allocated_storage == 0
    error_message = "Storage autoscaling must remain disabled to prevent unexpected growth."
  }

  assert {
    condition     = aws_db_instance.supportdesk.storage_encrypted
    error_message = "Database storage must be encrypted."
  }

  assert {
    condition     = !aws_db_instance.supportdesk.publicly_accessible && !aws_db_instance.supportdesk.multi_az
    error_message = "The demo database must be private and Single-AZ."
  }

  assert {
    condition     = aws_db_instance.supportdesk.manage_master_user_password
    error_message = "RDS must generate and manage the master password in Secrets Manager."
  }

  assert {
    condition     = toset(aws_db_instance.supportdesk.vpc_security_group_ids) == toset([aws_security_group.database.id])
    error_message = "The database must use only the restricted database security group."
  }

  assert {
    condition     = length(aws_db_subnet_group.supportdesk.subnet_ids) == 2
    error_message = "The database subnet group must span both private database subnets."
  }

  assert {
    condition     = aws_db_instance.supportdesk.backup_retention_period == 1 && aws_db_instance.supportdesk.deletion_protection
    error_message = "Automated backups and deletion protection must be enabled."
  }

  assert {
    condition     = !aws_db_instance.supportdesk.skip_final_snapshot
    error_message = "An approved teardown must create a final snapshot by default."
  }

  assert {
    condition     = aws_db_instance.supportdesk.monitoring_interval == 0 && !aws_db_instance.supportdesk.performance_insights_enabled
    error_message = "Optional paid database monitoring must remain disabled for the demo."
  }
}
