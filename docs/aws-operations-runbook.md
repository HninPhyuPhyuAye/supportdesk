# SupportDesk AWS operations runbook

## Purpose and safety rules

This runbook covers health checks, alarm response, application rollback,
database recovery, and cost-controlled teardown for the short-lived SupportDesk
demo in `ap-southeast-1`.

- Run commands from `infrastructure/terraform/application`.
- Use the `supportdesk` AWS CLI profile and confirm the active identity before
  any write operation.
- Never paste secret values, authorization URLs, database endpoints, account
  identifiers, or Terraform state into tickets or logs.
- Keep only read-only plan policies attached during normal operation.
- Attach apply policies only after reviewing a saved plan, then detach them and
  refresh the CLI session immediately after the approved change.
- Never apply a recovery or destroy plan until its affected resources and cost
  impact have been reviewed.

## Known-good production checkpoint

The verified demo has one healthy ARM64 Fargate task behind an Application Load
Balancer, a private PostgreSQL RDS instance, four healthy standard CloudWatch
alarms, and a successful GitHub authentication and ticket workflow.

Set the shared variables once for read-only commands:

```bash
export AWS_PROFILE=supportdesk
export AWS_REGION=ap-southeast-1
cd /Users/hninphyuphyuaye/Developer/supportdesk/infrastructure/terraform/application
```

Confirm the CLI identity without copying its output into public documentation:

```bash
aws sts get-caller-identity >/dev/null && echo "AWS identity confirmed"
```

## Routine health check

1. Confirm Terraform detects no drift with the same feature flags used by the
   deployed checkpoint:

   ```bash
   migration_tag="migration-$(git -C ../../.. rev-parse e9f3e6a)"

   terraform plan -detailed-exitcode -no-color \
     -var enable_ecs_service=true \
     -var enable_monitoring_alarms=true \
     -var enable_migration_task_definition=true \
     -var migration_image_tag="$migration_tag"
   ```

   Exit code `0` means no changes, `2` means changes are proposed, and any other
   code indicates an error. Do not apply an unexpected plan.

2. Check the public health endpoint:

   ```bash
   application_url="$(terraform output -raw application_url)"
   curl --fail --show-error "$application_url/api/health"
   ```

3. Check the service deployment and running task count:

   ```bash
   cluster_name="$(terraform output -raw ecs_cluster_name)"
   aws ecs describe-services \
     --region "$AWS_REGION" \
     --cluster "$cluster_name" \
     --services supportdesk-demo \
     --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}'
   ```

4. Check alarm states:

   ```bash
   aws cloudwatch describe-alarms \
     --region "$AWS_REGION" \
     --alarm-name-prefix supportdesk-demo- \
     --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}'
   ```

5. Read recent application logs without printing environment variables or
   secret values:

   ```bash
   aws logs tail /ecs/supportdesk-demo \
     --region "$AWS_REGION" \
     --since 15m
   ```

## Alarm response

CloudWatch may briefly report `INSUFFICIENT_DATA` while a new alarm waits for
metrics. These alarms treat missing data as non-breaching to avoid false alerts.

### Unhealthy ALB target

1. Confirm the ECS service has one running task.
2. Inspect target health and its reason code in the EC2 or ECS console.
3. Check `/api/health` and recent `/ecs/supportdesk-demo` logs.
4. Confirm the task security group accepts application traffic only from the
   load balancer security group.
5. If the failure followed a deployment, use the rollback procedure below.

### High ECS CPU or memory

1. Confirm the alarm has breached for the configured five-minute window.
2. Inspect logs for repeated requests, errors, or restart loops.
3. Check the ECS deployment and stopped-task reasons.
4. Roll back a recent application change when it caused the increase.
5. Do not increase task size or desired count without reviewing the cost change.

### Low RDS free storage

1. Confirm free storage remains below 2 GiB for the configured 15-minute window.
2. Stop unnecessary writes and investigate unexpected data growth.
3. Create and verify a manual snapshot before a storage change.
4. Do not enable storage autoscaling or increase storage without reviewing the
   ongoing cost and Terraform configuration.

## Application rollback

Images use immutable Git commit tags. Rollback creates a new task-definition
revision that refers to a previously verified image; it does not overwrite an
existing image.

1. Identify a previous scanned image tag in the private ECR repository.
2. Attach `SupportDeskRuntimeApplyAccess` temporarily and refresh the CLI.
3. Produce a saved plan using the previous tag:

   ```bash
   rollback_tag="<previous-verified-git-tag>"
   migration_tag="migration-$(git -C ../../.. rev-parse e9f3e6a)"

   terraform plan -out=/tmp/supportdesk-rollback.tfplan \
     -var enable_ecs_service=true \
     -var enable_monitoring_alarms=true \
     -var enable_migration_task_definition=true \
     -var migration_image_tag="$migration_tag" \
     -var container_image_tag="$rollback_tag"
   ```

4. Verify the plan changes only the application task definition and ECS service.
5. Apply the saved plan only after approval:

   ```bash
   terraform apply /tmp/supportdesk-rollback.tfplan
   ```

6. Wait for one healthy target, test login and ticket operations, detach the
   apply policy, refresh the CLI, and rerun the no-drift plan.

The ECS deployment circuit breaker is enabled with automatic rollback for a
failed rolling deployment. AWS describes task replacement and immutable digest
resolution in the
[Amazon ECS deployment guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html).

## Database recovery

RDS automated backups are retained for one day, and an approved teardown creates
a final manual snapshot. Restoring a snapshot creates a **new** database
instance; it does not restore data into the existing instance.

1. Stop or scale down the application before recovery to prevent new writes.
2. Select the required automated recovery point or verified manual snapshot.
3. Restore it to a temporary, private DB instance in the SupportDesk database
   subnet group and database security group.
4. Validate connectivity, schema migrations, and ticket data from a controlled
   task. Do not make the restored database public.
5. Update the application secret only after the restored database is verified.
6. Deploy a new task revision, test the complete application flow, and retain
   the old database until recovery is confirmed.
7. Import any long-lived restored resource into Terraform or deliberately
   reconcile the configuration before the next apply.

AWS documents that snapshot restore creates a new DB instance in the
[RDS snapshot restore guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html).

## Cost-controlled teardown

Teardown is destructive and requires explicit approval. Preserve the ECR
repository and portfolio image by destroying only the application Terraform
root. The final RDS snapshot and seven-day Secrets Manager recovery window can
continue to incur storage charges after the live environment is removed.

1. Verify Git is clean, CI is passing, and production evidence was captured.
2. Confirm no migration task is running and note the latest healthy image tag.
3. Confirm there is no existing snapshot named `supportdesk-demo-final`; rename
   or intentionally remove an obsolete snapshot before proceeding.
4. Temporarily attach the network, database, and runtime apply policies. The
   monitoring creation policy and migration policies are not required.
5. Disable RDS deletion protection with a separate reviewed plan and apply:

   ```bash
   migration_tag="migration-$(git -C ../../.. rev-parse e9f3e6a)"

   terraform plan -out=/tmp/supportdesk-disable-protection.tfplan \
     -var enable_ecs_service=true \
     -var enable_monitoring_alarms=true \
     -var enable_migration_task_definition=true \
     -var migration_image_tag="$migration_tag" \
     -var database_deletion_protection=false

   terraform apply /tmp/supportdesk-disable-protection.tfplan
   ```

6. Create a saved destroy plan that retains the final snapshot:

   ```bash
   terraform plan -destroy -out=/tmp/supportdesk-destroy.tfplan \
     -var enable_ecs_service=true \
     -var enable_monitoring_alarms=true \
     -var enable_migration_task_definition=true \
     -var migration_image_tag="$migration_tag" \
     -var database_deletion_protection=false \
     -var database_skip_final_snapshot=false
   ```

7. Review every deletion. The plan must not include the separate ECR root,
   unrelated IAM users or policies, or unrelated AWS resources.
8. Apply only the reviewed saved destroy plan:

   ```bash
   terraform apply /tmp/supportdesk-destroy.tfplan
   ```

9. Confirm the ECS service, ALB, Fargate tasks, RDS instance, CloudWatch alarms,
   log group, application secret, public IPv4 assignment, and VPC are gone.
10. Verify the final RDS snapshot exists and is available.
11. Detach every apply policy, refresh the CLI, and review AWS Billing and Cost
    Explorer for remaining resources.

HashiCorp recommends reviewing a speculative destroy plan before deprovisioning
ephemeral infrastructure; see the
[Terraform destroy command reference](https://developer.hashicorp.com/terraform/cli/commands/destroy).

## Post-incident record

Record the UTC start and end time, detected symptom, affected component, alarm
state, relevant log timestamps, root cause, corrective action, validation
results, and follow-up work. Never include secrets, credentials, full database
URLs, account identifiers, or OAuth callback query strings.
