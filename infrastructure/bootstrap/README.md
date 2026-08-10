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
master password. Terraform tests and plan review enforce the remaining cost
controls that IAM does not expose as condition keys.

Attach the database apply policy only for an approved database apply or
teardown, then detach it immediately. Keep the database plan policy for drift
detection after deployment.

RDS also requires the account-level `AWSServiceRoleForRDS` service-linked role.
An administrator must create that role if it does not already exist. Do not
grant `iam:CreateServiceLinkedRole` to `supportdesk-deployer`.
