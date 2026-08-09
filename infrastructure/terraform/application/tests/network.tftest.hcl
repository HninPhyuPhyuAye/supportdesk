mock_provider "aws" {
  override_during = plan

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    }
  }
}

run "network_topology" {
  command = apply

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "The load balancer and application require two public subnets."
  }

  assert {
    condition     = length(aws_subnet.database) == 2
    error_message = "The RDS DB subnet group requires two private database subnets."
  }

  assert {
    condition = alltrue([
      for subnet in values(aws_subnet.public) : !subnet.map_public_ip_on_launch
    ])
    error_message = "Public IP assignment must be an explicit ECS service decision."
  }

  assert {
    condition = alltrue([
      for subnet in values(aws_subnet.database) : !subnet.map_public_ip_on_launch
    ])
    error_message = "Database subnets must never assign public IP addresses."
  }

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "The public route table must send internet traffic to the internet gateway."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.application_from_load_balancer.referenced_security_group_id == aws_security_group.load_balancer.id
    error_message = "Application ingress must be restricted to the load balancer security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database_from_application.referenced_security_group_id == aws_security_group.application.id
    error_message = "Database ingress must be restricted to the application security group."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.application_to_database.referenced_security_group_id == aws_security_group.database.id
    error_message = "Application database egress must target only the database security group."
  }
}
