# SupportDesk bootstrap IAM policies

These customer-managed IAM policy documents bootstrap the
`supportdesk-deployer` user. They must be created or updated from an AWS
administrator session and then attached to the deployment user.

| Policy file | Purpose |
| --- | --- |
| `supportdesk-ecr-policy.json` | Manage only the SupportDesk ECR repository and list private repositories in Singapore. |
| `supportdesk-network-plan-policy.json` | Read Singapore VPC inventory so Terraform can produce a real network plan. |
| `supportdesk-network-apply-policy.json` | Temporarily create or remove only the tagged network resource types in the reviewed plan. |
| `supportdesk-database-plan-policy.json` | Read Singapore RDS inventory and RDS-managed secret metadata without reading secret values. |
| `supportdesk-database-apply-policy.json` | Temporarily create or remove only the cost-controlled SupportDesk PostgreSQL resources. |
| `supportdesk-ecs-tasks-trust-policy.json` | Let only the ECS tasks service in Singapore assume the execution and application task roles. |
| `supportdesk-ecs-execution-policy.json` | Let the ECS agent pull only the SupportDesk image, write its log streams, and read its application secret. |
| `supportdesk-runtime-plan-policy.json` | Read ECS, load-balancer, log-group, and application-secret metadata without reading secret values. |
| `supportdesk-runtime-apply-policy.json` | Temporarily manage only the named SupportDesk ECS, ALB, log-group, and application-secret metadata resources. |
| `supportdesk-monitoring-create-policy.json` | Temporarily create and tag the four reviewed CloudWatch alarms in Singapore. |
| `supportdesk-migration-secret-policy.json` | Temporarily let the ECS execution role inject the RDS-managed master credential into the migration task. |
| `supportdesk-migration-run-policy.json` | Temporarily run, observe, or stop only the small SupportDesk migration task. |

The network plan policy contains only `Describe` actions. It cannot create,
modify, tag, or delete AWS resources. The actions use `Resource: "*"` because
the EC2 inventory APIs do not support resource-level authorization. The
`aws:RequestedRegion` condition restricts requests to `ap-southeast-1`.

Do not grant the deployment user permission to create or update IAM policies.
An administrator should review and attach each bootstrap policy, preserving
separation between infrastructure deployment and permission administration.

The network apply policy should be attached only immediately before an approved
apply or teardown and detached again afterward. It cannot create compute,
database, load-balancer, Elastic IP, or NAT Gateway resources. New taggable
network resources must include the SupportDesk demo tags, and destructive
resource actions require those tags to already be present.

The database plan policy is read-only and does not include
`secretsmanager:GetSecretValue`. The database apply policy limits creation to
the named SupportDesk demo resources and requires PostgreSQL, `db.t4g.micro`,
20 GiB storage, encryption, private VPC access, Single-AZ, and an RDS-managed
master password. During an approved teardown, it can create only the named final
snapshot from the named SupportDesk database. Terraform tests and plan review
enforce the remaining cost controls that IAM does not expose as condition keys.

Attach the database apply policy only for an approved database apply or
teardown, then detach it immediately. Keep the database plan policy for drift
detection after deployment.

RDS also requires the account-level `AWSServiceRoleForRDS` service-linked role.
An administrator must create that role if it does not already exist. Do not
grant `iam:CreateServiceLinkedRole` to `supportdesk-deployer`.

The ECS runtime uses two administrator-created roles with the same trust policy:

- `supportdesk-ecs-execution` receives the execution policy because the ECS
  agent pulls the private image, writes container logs, and injects secrets.
- `supportdesk-ecs-task` intentionally receives no permissions yet because the
  SupportDesk application does not call AWS APIs directly.

The runtime apply policy can pass only those two roles and only to
`ecs-tasks.amazonaws.com`. It deliberately excludes `secretsmanager:PutSecretValue`;
an administrator populates the application secret outside Terraform so the
plaintext value never enters Terraform state. The apply policy must be detached
immediately after an approved runtime apply or teardown.

CloudWatch does not reliably authorize a not-yet-created alarm through existing
resource tags. Alarm creation therefore uses the separate, short-lived
monitoring create policy with only `PutMetricAlarm` and `TagResource` actions.
Attach it only for a reviewed monitoring apply and detach it immediately after
the alarms exist. The runtime apply policy manages only existing, tagged
SupportDesk alarms, while the runtime plan policy remains read-only.

AWS does not support resource-level authorization for
`ecs:DescribeTaskDefinition` or `ecs:DeregisterTaskDefinition`. Those two
statements therefore use `Resource: "*"` with a Singapore-region condition.
All task-definition creation and tagging remains limited to the
`supportdesk-demo` family, and the apply policy is temporary.

Amazon ECS and Elastic Load Balancing also use account-level service-linked
roles. An administrator must create them if they do not already exist. Do not
grant `iam:CreateServiceLinkedRole` to the deployment user.

The one-off migration task creates or rotates the restricted
`supportdesk_app` PostgreSQL login and runs committed Prisma migrations as that
login. Before the task runs, temporarily attach
`supportdesk-migration-secret-policy.json` to the ECS execution role and
`supportdesk-migration-run-policy.json` to the deployment user. Detach both as
soon as the migration exits successfully. The migration policy cannot update
secrets, and the run policy cannot create a service or run another task family.
