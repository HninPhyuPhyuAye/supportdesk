# SupportDesk AWS teardown record

## Outcome

The short-lived SupportDesk demo environment was successfully archived on
11 August 2026 after its application workflow, infrastructure, monitoring, and
CI evidence were captured.

The teardown removed all resources managed by the application Terraform root:

- ECS service, cluster, application task definition, and migration task
  definition;
- Application Load Balancer, listener, target group, and public task address;
- private RDS PostgreSQL instance and RDS-managed runtime resources;
- CloudWatch log group and four metric alarms;
- application secret, which entered its seven-day recovery window; and
- VPC, subnets, routes, internet gateway, and security groups.

Read-only verification found zero remaining Terraform state resources, live
SupportDesk databases, alarms, VPCs, load balancers, or active ECS clusters.

## Retained artifacts

- The final RDS snapshot is available for controlled recovery.
- The separate ECR Terraform root and its three immutable images remain for
  portfolio evidence and possible future redeployment.
- GitHub source code, CI history, architecture documentation, runbook, and
  sanitized deployment screenshots remain available.
- IAM apply policies remain defined for repeatable administration but are
  detached from the deployment user. Read-only plan policies remain attached.

The retained snapshot and ECR images can incur storage charges. They should be
reviewed periodically and removed when recovery or redeployment is no longer
required.

## Change controls used

1. Confirmed a clean Git worktree and successful CI run.
2. Confirmed the final-snapshot identifier was unused and ECR was outside the
   application Terraform state.
3. Generated and reviewed a one-resource plan before disabling RDS deletion
   protection.
4. Generated a saved destroy plan and confirmed every proposed change was a
   deletion, final snapshots were enabled, and ECR changes were zero.
5. Applied only the reviewed saved plan.
6. Detached all temporary write policies and refreshed the CLI session.

## Issue and resolution

The first destroy apply stopped safely at RDS because the database apply policy
allowed `DeleteDBInstance` but did not include the dependent
`CreateDBSnapshot` permission needed for a final snapshot. The database and its
data remained intact.

The policy was updated to allow `CreateDBSnapshot` only for the named
SupportDesk database and final snapshot in Singapore. An automated policy test
was added to prevent this scope from broadening. A fresh destroy plan was then
generated from the partially updated Terraform state and applied successfully.

## Lessons demonstrated

- Saved Terraform plans make destructive scope reviewable before execution.
- Deletion protection and final snapshots provide independent data safeguards.
- Partial Terraform failure can be recovered safely by fixing the specific IAM
  gap and generating a new plan instead of reusing stale state or plans.
- Least-privilege policies should include documented dependent actions and
  automated guardrail tests.
- Operational completion includes post-change verification, permission removal,
  cost review, and evidence capture—not only a successful apply.
