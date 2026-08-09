# SupportDesk bootstrap IAM policies

These customer-managed IAM policy documents bootstrap the
`supportdesk-deployer` user. They must be created or updated from an AWS
administrator session and then attached to the deployment user.

| Policy file | Purpose |
| --- | --- |
| `supportdesk-ecr-policy.json` | Manage only the SupportDesk ECR repository and list private repositories in Singapore. |
| `supportdesk-network-plan-policy.json` | Read Singapore VPC inventory so Terraform can produce a real network plan. |

The network plan policy contains only `Describe` actions. It cannot create,
modify, tag, or delete AWS resources. The actions use `Resource: "*"` because
the EC2 inventory APIs do not support resource-level authorization. The
`aws:RequestedRegion` condition restricts requests to `ap-southeast-1`.

Do not grant the deployment user permission to create or update IAM policies.
An administrator should review and attach each bootstrap policy, preserving
separation between infrastructure deployment and permission administration.

Write access for the application network will be defined in a separate policy
and reviewed only after the read-only Terraform plan is available.
