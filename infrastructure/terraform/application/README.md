# SupportDesk application infrastructure

This Terraform root module will manage the short-lived SupportDesk AWS demo
environment in `ap-southeast-1`. The first checkpoint defines only networking
and security boundaries:

- one VPC;
- two public subnets across two Availability Zones;
- two private database subnets across two Availability Zones;
- an internet gateway and public route table;
- no NAT Gateway; and
- separate load balancer, application, and database security groups.

The database subnets have no internet route. The application security group
accepts traffic only from the load balancer and can connect to PostgreSQL only
through the database security group.

## Local validation

```bash
terraform init -backend=false
terraform fmt -check
terraform validate
terraform test
```

The test uses Terraform's mocked AWS provider. Its mock apply exists only in
memory, does not authenticate to AWS, and does not create cloud resources.

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
