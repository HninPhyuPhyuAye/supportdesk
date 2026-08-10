resource "aws_db_subnet_group" "supportdesk" {
  name       = "${local.name_prefix}-database"
  subnet_ids = [for key in sort(keys(aws_subnet.database)) : aws_subnet.database[key].id]

  tags = {
    Name = "${local.name_prefix}-database"
  }
}

resource "aws_db_instance" "supportdesk" {
  identifier = "${local.name_prefix}-postgres"

  engine                   = "postgres"
  engine_version           = var.database_engine_version
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"
  instance_class           = var.database_instance_class

  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = 0
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = var.database_name
  username                    = var.database_master_username
  manage_master_user_password = true
  port                        = var.database_port

  db_subnet_group_name   = aws_db_subnet_group.supportdesk.name
  vpc_security_group_ids = [aws_security_group.database.id]
  network_type           = "IPV4"
  publicly_accessible    = false
  multi_az               = false

  auto_minor_version_upgrade = true
  backup_retention_period    = var.database_backup_retention_days
  backup_window              = "18:00-18:30"
  maintenance_window         = "sun:19:00-sun:19:30"
  copy_tags_to_snapshot      = true
  delete_automated_backups   = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 0
  performance_insights_enabled    = false

  deletion_protection       = var.database_deletion_protection
  skip_final_snapshot       = var.database_skip_final_snapshot
  final_snapshot_identifier = var.database_skip_final_snapshot ? null : "${local.name_prefix}-final"

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
