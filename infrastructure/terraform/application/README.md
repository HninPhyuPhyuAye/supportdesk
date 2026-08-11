# SupportDesk application infrastructure

This Terraform root module defines the short-lived SupportDesk AWS demo
environment in `ap-southeast-1`. The verified deployment included:

- one VPC;
- two public subnets across two Availability Zones;
- two private database subnets across two Availability Zones;
- an internet gateway and public route table;
- no NAT Gateway; and
- separate load balancer, application, and database security groups; and
- a private, encrypted, Single-AZ RDS for PostgreSQL instance with an
  RDS-managed master credential;
- one ECS cluster and one running ARM64 Fargate application task;
- an internet-facing Application Load Balancer and `/api/health` target group;
- a seven-day CloudWatch Logs group;
- four standard CloudWatch alarms for ALB, ECS, and RDS health; and
- an application-secret container populated outside Terraform.

The database subnets have no internet route. The application security group
accepts traffic only from the load balancer and can connect to PostgreSQL only
through the database security group.

The application root was destroyed after verification and its Terraform state
now contains no managed resources. The final RDS snapshot and separate ECR root
remain. A future deployment is still cost controlled by default: both
`enable_ecs_service` and `enable_monitoring_alarms` are `false` unless explicitly
enabled. Fargate, public IPv4, ALB, RDS, Secrets Manager, and CloudWatch usage
can incur charges while deployed.

The verified separate one-off ARM64 migration task definition:

- runs as a non-root user with a read-only root filesystem;
- receives both credentials from Secrets Manager at runtime;
- creates or rotates the restricted `supportdesk_app` database login;
- transfers ownership only for objects in the application schema;
- applies committed Prisma migrations as `supportdesk_app`; and
- exits instead of creating a continuously running service.

## Monitoring

Set `enable_monitoring_alarms = true` together with
`enable_ecs_service = true` to create:

- an alarm when at least one ALB target is unhealthy for two minutes;
- ECS CPU and memory alarms when utilization exceeds 80% for five minutes; and
- an RDS storage alarm when free space remains below 2 GiB for 15 minutes.

Missing data does not trigger these alarms, and no notification actions are
configured yet. Alarm creation uses the temporary
`SupportDeskMonitoringCreateAccess` policy. Detach that policy and the runtime
apply policy immediately after an approved apply; retain only the read-only
runtime plan policy for drift detection.

## Local validation

```bash
terraform init -backend=false
terraform fmt -check
terraform validate
terraform test
```

The test uses Terraform's mocked AWS provider. Its mock apply exists only in
memory, does not authenticate to AWS, and does not create cloud resources.

RDS generates and rotates the master password in Secrets Manager. Terraform
stores the resulting secret ARN, not the plaintext password. The master account
is reserved for controlled bootstrap and migrations; the application will use
a separate least-privilege database user created during the migration stage.

Terraform creates only the application secret container, not a secret version.
The `DATABASE_URL`, Better Auth secret, and GitHub OAuth values must be populated
outside Terraform so their plaintext values do not enter Terraform state. The
task definition injects those values by JSON key at runtime.

The task definitions reference administrator-created
`supportdesk-ecs-execution` and `supportdesk-ecs-task` IAM roles. Terraform does
not create those roles. The roles now exist, and the runtime read-only policy is
attached to the deployment user. All write and migration policies remain
temporary.

## Migration image

Build the migration target using the same pinned Node base image:

```bash
docker build --target migrator --tag supportdesk-migrator:local .
```

The migration task definition is disabled by default. Enable it only with an
immutable image tag after that image has been pushed to ECR:

```bash
terraform plan \
  -var='enable_migration_task_definition=true' \
  -var='migration_image_tag=migration-<git-sha>'
```

The temporary RDS-master-secret permission belongs on the execution role only
while the one-off migration task runs. Detach it immediately afterward.

## Read-only AWS plan

The attached read-only network, database, and runtime plan policies support
drift checks for the deployed checkpoint without reading secret values. Run:

```bash
terraform plan -out=supportdesk-application.tfplan
terraform show supportdesk-application.tfplan
```

Planning reads existing network inventory but does not create resources. A
saved plan is ignored by Git and must be reviewed before any apply command is
considered.

## Controlled apply access

Apply policies are temporary. Attach the checkpoint-specific write policy only
for an explicitly approved apply or teardown, and detach it immediately
afterward. Keep only read-only policies attached for drift detection.

Do not run `terraform apply` until the plan, IAM permissions, expected resources,
and cost controls have been reviewed. Initializing, validating, and testing this
module locally does not create AWS resources. The deployed ALB and secrets must
be removed promptly after the portfolio demonstration.

The complete design and teardown objective are documented in
[`docs/aws-architecture.md`](../../../docs/aws-architecture.md).
