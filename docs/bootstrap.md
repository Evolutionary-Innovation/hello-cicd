# Bootstrap Guide

The bootstrap stack (`bootstrap/`) creates what the main stack and CI depend on:

- the S3 state bucket (versioned, SSE-S3, public access blocked, `prevent_destroy`)
- the GitHub OIDC identity provider
- the GitHub Actions IAM role and its scoped policy (`ci-policy.tf`)

It is applied **manually with admin credentials**. CI never runs it, so the pipeline cannot modify its own access.

## Prerequisites

- Terraform >= 1.10, AWS CLI, admin credentials for the target account (`aws sts get-caller-identity`).
- `bootstrap/terraform.tfvars` and `bootstrap/backend.hcl` configured (use `scripts/configure-project.sh`).
- A globally unique `state_bucket_name`.

## Fresh account

The state bucket does not exist yet, so the first apply uses local state and then migrates.

```bash
cd bootstrap

# 1. Create everything with local state
mv backend.tf backend.tf.off
terraform init
terraform plan -out=tfplan          # expect only creates
terraform apply tfplan

# 2. Move the state into the bucket it just created
mv backend.tf.off backend.tf
terraform init -migrate-state -backend-config=backend.hcl -force-copy
rm -f terraform.tfstate terraform.tfstate.backup tfplan

# 3. Read the role ARN for GitHub
terraform output -raw github_actions_role_arn
```

Then set the GitHub variables (see [OIDC Guide](oidc.md)):

```bash
gh variable set AWS_REGION   --body "<region>"
gh variable set AWS_ROLE_ARN --body "<role arn>"
```

Afterwards, re-init normally: `terraform init -reconfigure -backend-config=backend.hcl`.

## Changing CI permissions later

Edit `ci-policy.tf`, then `terraform plan` / `terraform apply` in `bootstrap/` with admin credentials. The next pipeline run uses the new policy. Keep the change narrow and review the plan: it should update only `aws_iam_policy.github_actions`.

## Gotchas

- **Account already has the GitHub OIDC provider.** An account can hold only one provider for `token.actions.githubusercontent.com`. If the apply fails with `EntityAlreadyExists`, import it into this stack: `terraform import aws_iam_openid_connect_provider.github arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com`. Be aware that destroying either project's bootstrap would then remove the shared provider.
- **Shared state bucket.** Several projects can share one bucket: each uses its own key prefix (`<project_name>/terraform.tfstate`) and the CI policy only grants that prefix.
- **Private repositories.** The OIDC subject uses numeric IDs, so a renamed or recreated repository does not inherit access. Supply `--owner-id` / `--repo-id` to the configure script if the repository is private.
- **Legacy role name.** `github_role_name` is optional; unset it gives `<project_name>-github-actions`. This repository keeps `github-terraform-role` so the existing `AWS_ROLE_ARN` stays valid.
- **Never** run `terraform destroy` in `bootstrap/`. The bucket has `prevent_destroy` for that reason.
