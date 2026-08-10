# SupportDesk application infrastructure

This Terraform root module manages the short-lived SupportDesk AWS demo
environment in `ap-southeast-1`. The deployed checkpoint currently includes
the networking and security boundaries:

- one VPC;
- two public subnets across two Availability Zones;
- two private database subnets across two Availability Zones;
- an internet gateway and public route table;
- no NAT Gateway; and
- separate load balancer, application, and database security groups.

The database subnets have no internet route. The application security group
accepts traffic only from the load balancer and can connect to PostgreSQL only
through the database security group.

The next checkpoint is implemented in Terraform but has **not** been applied:

- a private, encrypted, Single-AZ RDS for PostgreSQL instance;
- a two-AZ RDS DB subnet group;
- an RDS-managed master credential in Secrets Manager;
- one day of automated backup retention;
- deletion protection and a final snapshot by default; and
- no storage autoscaling, Enhanced Monitoring, or Performance Insights.

RDS and its managed Secrets Manager secret incur charges only after an approved
apply. Local validation and mocked tests create no AWS resources.

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

## Read-only AWS plan

Before producing a real AWS plan, an administrator must attach the read-only
`infrastructure/bootstrap/supportdesk-network-plan-policy.json` policy to the
deployment user. Then run:

```bash
terraform plan -out=supportdesk-network.tfplan
terraform show supportdesk-network.tfplan
```

Planning reads existing network inventory but does not create resources. A
saved plan is ignored by Git and must be reviewed before any apply command is
considered.

## Controlled apply access

The separate `infrastructure/bootstrap/supportdesk-network-apply-policy.json`
policy contains the write actions needed by this network configuration. Attach
it only for an explicitly approved apply or teardown, and detach it immediately
afterward. Keep the read-only plan policy attached for drift detection.

Do not run `terraform apply` until the plan, IAM permissions, expected resources,
and cost controls have been reviewed. Initializing and validating this module
locally does not create AWS resources.

The complete design and teardown objective are documented in
[`docs/aws-architecture.md`](../../../docs/aws-architecture.md).
