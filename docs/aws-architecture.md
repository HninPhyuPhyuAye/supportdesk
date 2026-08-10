# SupportDesk AWS deployment architecture

## Status

This document describes the AWS runtime architecture. The ECR repository,
application network, private RDS instance, and RDS-managed master secret are
deployed. The ECS cluster, task definition, load balancer, seven-day log group,
and application-secret metadata are implemented and tested locally but have not
been applied. The Fargate service is disabled by default.

The first deployment will be short-lived and cost-controlled. Terraform will
also expose the settings needed to demonstrate how the design scales to a
high-availability production configuration.

## Architecture

```mermaid
flowchart TB
    user["SupportDesk user"] --> alb["Application Load Balancer\npublic subnets in two AZs"]
    alb --> ecs["Amazon ECS on Fargate\nARM64 SupportDesk task"]

    ecr["Amazon ECR\nimmutable, scanned image"] --> ecs
    secrets["AWS Secrets Manager\ndatabase and auth secrets"] --> ecs
    ecs --> rds["Amazon RDS for PostgreSQL\nprivate subnets"]
    ecs --> logs["Amazon CloudWatch Logs\n7-day demo retention"]
    alb --> alarms["CloudWatch health alarms"]

    github["GitHub Actions\nOIDC federation"] --> ecr
    github --> ecs
```

## Network design

- Region: Asia Pacific (Singapore), `ap-southeast-1`.
- One VPC with DNS resolution and DNS hostnames enabled.
- Two public subnets in separate Availability Zones for the load balancer and
  Fargate tasks.
- Two private database subnets in separate Availability Zones for the RDS DB
  subnet group.
- An internet gateway for public ingress and task egress.
- No NAT Gateway in the demo environment. Each Fargate task receives a public
  IP for outbound access, while its security group accepts inbound traffic only
  from the load balancer security group.
- The database receives no public IP and accepts PostgreSQL traffic only from
  the Fargate task security group.

The public task IP is a deliberate demo cost trade-off. A production version
would place tasks in private subnets and use redundant NAT Gateways or VPC
endpoints for ECR, CloudWatch Logs, and Secrets Manager.

## Cost-controlled demo profile

| Component | Demo setting | Production upgrade path |
| --- | --- | --- |
| Fargate | One Linux/ARM64 task, 0.25 vCPU and 0.5 GB memory | Two or more tasks across Availability Zones with autoscaling |
| RDS | Single-AZ PostgreSQL, small Graviton instance, 20 GB general-purpose storage | Multi-AZ deployment with longer backup retention |
| Networking | No NAT Gateway; tightly restricted public task IP | Private tasks with redundant egress or VPC endpoints |
| Load balancer | One internet-facing ALB used only during the demonstration | HTTPS listener, ACM certificate, custom domain and AWS WAF where required |
| Logs | Seven-day CloudWatch retention | Retention based on compliance and operational requirements |
| Images | ECR lifecycle keeps the latest three images | Retention based on release and rollback policy |

The VPC, subnets, route tables, security groups, and internet gateway do not
have an hourly charge by themselves. Fargate tasks, public IPv4 addresses, the
load balancer, RDS, Secrets Manager, and CloudWatch usage can incur charges
while deployed.

## Security controls

- Run the container as the non-root `nextjs` user.
- Use the scanned, immutable ECR image identified by a Git commit tag.
- Keep RDS private and encrypted at rest.
- Generate the database password instead of committing it to Git.
- Store application secrets in Secrets Manager and inject them into the ECS
  task at runtime.
- Create only the application secret container with Terraform and populate its
  value outside Terraform so plaintext credentials do not enter state.
- Let RDS generate and rotate its master credential in Secrets Manager so the
  plaintext password never enters Git or Terraform state.
- Reserve the database master account for controlled bootstrap and migrations;
  run the application with a separate least-privilege database user.
- Give the ECS task, ECS execution role, and GitHub deployment role separate
  least-privilege IAM policies.
- Use GitHub Actions OIDC federation instead of long-lived AWS access keys.
- Restrict security-group paths to ALB-to-task and task-to-database traffic.
- Send application logs to CloudWatch without logging secret values.

## Availability and data protection

The network and load balancer span two Availability Zones from the beginning.
The demo runs one application task and a Single-AZ database to control costs.
The production profile increases the application desired count to at least two
and enables RDS Multi-AZ without redesigning the network.

RDS automated backups, deletion protection, and a final snapshot are configured.
Application and load-balancer health checks are included in the local runtime
configuration. CloudWatch alarms remain to be added before the live
demonstration. A recovery runbook will document database restoration and
application rollback to an earlier immutable ECR tag.

## Deployment sequence

1. Validate and review the Terraform plan without creating resources.
2. Provision networking and security groups.
3. Provision RDS and its managed Secrets Manager credential. **Completed.**
4. Create the ECS execution and task roles and review the runtime plan and cost.
5. Populate the application secret outside Terraform.
6. Apply Prisma migrations through a controlled one-off ECS task.
7. Provision the ECS task definition, service, load balancer, and logging.
8. Update the GitHub OAuth callback and production application URL.
9. Test authentication, ticket operations, health checks, logs, and alarms.
10. Capture architecture and operational evidence for the portfolio.
11. Create a final database snapshot and destroy billable demo resources.

## Teardown objective

The teardown runbook will remove the ECS service, load balancer, RDS instance,
Secrets Manager secret, public IPv4 assignments, and application VPC. The ECR
repository and its single portfolio image can remain because their storage is
within the new-customer private-repository allowance.

## Pricing references

- [AWS Fargate pricing](https://aws.amazon.com/fargate/pricing/)
- [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/)
- [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/)
