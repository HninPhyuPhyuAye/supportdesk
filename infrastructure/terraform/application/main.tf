data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  name_prefix        = "${var.project_name}-${var.environment}"

  public_subnets = {
    for index, cidr in var.public_subnet_cidrs : tostring(index) => {
      availability_zone = local.availability_zones[index]
      cidr_block        = cidr
    }
  }

  database_subnets = {
    for index, cidr in var.database_subnet_cidrs : tostring(index) => {
      availability_zone = local.availability_zones[index]
      cidr_block        = cidr
    }
  }
}

resource "aws_vpc" "supportdesk" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "supportdesk" {
  vpc_id = aws_vpc.supportdesk.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.supportdesk.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${each.value.availability_zone}"
    Tier = "public"
  }
}

resource "aws_subnet" "database" {
  for_each = local.database_subnets

  vpc_id                  = aws_vpc.supportdesk.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-database-${each.value.availability_zone}"
    Tier = "database"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.supportdesk.id

  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.supportdesk.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.supportdesk.id

  tags = {
    Name = "${local.name_prefix}-database"
  }
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  route_table_id = aws_route_table.database.id
  subnet_id      = each.value.id
}

resource "aws_security_group" "load_balancer" {
  name_prefix            = "${local.name_prefix}-alb-"
  description            = "Controls public traffic to the SupportDesk load balancer."
  vpc_id                 = aws_vpc.supportdesk.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${local.name_prefix}-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "application" {
  name_prefix            = "${local.name_prefix}-app-"
  description            = "Allows only load-balancer traffic into SupportDesk tasks."
  vpc_id                 = aws_vpc.supportdesk.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${local.name_prefix}-app"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "database" {
  name_prefix            = "${local.name_prefix}-database-"
  description            = "Allows PostgreSQL traffic only from SupportDesk tasks."
  vpc_id                 = aws_vpc.supportdesk.id
  revoke_rules_on_delete = true

  tags = {
    Name = "${local.name_prefix}-database"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.load_balancer.id
  cidr_ipv4         = each.value
  description       = "Public HTTP access for the temporary demo."
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "load_balancer_to_application" {
  security_group_id            = aws_security_group.load_balancer.id
  referenced_security_group_id = aws_security_group.application.id
  description                  = "Forward HTTP traffic to SupportDesk tasks."
  from_port                    = var.app_port
  ip_protocol                  = "tcp"
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_ingress_rule" "application_from_load_balancer" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.load_balancer.id
  description                  = "Accept traffic only from the load balancer."
  from_port                    = var.app_port
  ip_protocol                  = "tcp"
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "application_https" {
  security_group_id = aws_security_group.application.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Reach AWS APIs, GitHub OAuth, and other HTTPS endpoints."
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "application_to_database" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.database.id
  description                  = "Connect to PostgreSQL."
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}

resource "aws_vpc_security_group_ingress_rule" "database_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id
  description                  = "Accept PostgreSQL only from SupportDesk tasks."
  from_port                    = var.database_port
  ip_protocol                  = "tcp"
  to_port                      = var.database_port
}
