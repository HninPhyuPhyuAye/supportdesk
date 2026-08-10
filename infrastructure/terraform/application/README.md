# SupportDesk application infrastructure

This Terraform root module manages the short-lived SupportDesk AWS demo
environment in `ap-southeast-1`. The deployed checkpoint currently includes:

- one VPC;
- two public subnets across two Availability Zones;
- two private database subnets across two Availability Zones;
- an internet gateway and public route table;
- no NAT Gateway; and
- separate load balancer, application, and database security groups; and
- a private, encrypted, Single-AZ RDS for PostgreSQL instance with an
  RDS-managed master credential.

The database subnets have no internet route. The application security group
accepts traffic only from the load balancer and can connect to PostgreSQL only
through the database security group.

The ECS runtime checkpoint is implemented and tested locally but has **not**
been applied. It defines:

- one ECS cluster with paid Container Insights disabled;
- an ARM64 Fargate task fixed at 0.25 vCPU and 0.5 GB memory;
- an internet-facing Application Load Balancer and `/api/health` checks;
- a seven-day CloudWatch Logs group;
- application-secret metadata in Secrets Manager; and
- an ECS service that is disabled by default with `enable_ecs_service = false`.

The deployed RDS instance and its managed secret continue to incur charges.
Local validation and mocked tests create no AWS resources. No ECS cluster,
load balancer, CloudWatch log group, application secret, task definition, or
Fargate service is created until a later explicitly approved apply.

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

The task definition references administrator-created
`supportdesk-ecs-execution` and `supportdesk-ecs-task` IAM roles. Terraform does
not create those roles. They and a tightly scoped runtime deployment policy must
be reviewed before producing a real runtime plan.

## Read-only AWS plan

The currently attached read-only network and database plan policies support
drift checks for the deployed checkpoint. A separate least-privilege runtime
plan policy is still required before planning the ECS checkpoint. After that
policy is reviewed and attached, run:

```bash
terraform plan -out=supportdesk-runtime.tfplan
terraform show supportdesk-runtime.tfplan
```

Planning reads existing network inventory but does not create resources. A
saved plan is ignored by Git and must be reviewed before any apply command is
considered.

## Controlled apply access

Apply policies are temporary. Attach the checkpoint-specific write policy only
for an explicitly approved apply or teardown, and detach it immediately
afterward. Keep only read-only policies attached for drift detection.

Do not run `terraform apply` until the plan, IAM permissions, expected resources,
and cost controls have been reviewed. Applying the current runtime configuration
would create a billable load balancer and application secret even while the
Fargate service remains disabled. Initializing, validating, and testing this
module locally does not create AWS resources.

The complete design and teardown objective are documented in
[`docs/aws-architecture.md`](../../../docs/aws-architecture.md).
