# SupportDesk ECR infrastructure

This Terraform root module manages only the private Amazon ECR repository used
to store SupportDesk container images in `ap-southeast-1`.

The repository uses immutable tags, AES-256 encryption, scan-on-push, and a
lifecycle policy that retains the three newest images. Accidental deletion of a
non-empty repository is disabled by default.

## Safe workflow

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=supportdesk.tfplan
```

Review the plan before running `terraform apply supportdesk.tfplan`. Applying a
plan changes AWS and must be an explicit decision.

For intentional final cleanup of a repository that still contains images, use
`-var='allow_force_delete=true'` only after confirming the target repository.
