# OIDC Guide

GitHub Actions authenticates to AWS with OpenID Connect. No AWS access keys exist anywhere.

## How it works

1. A workflow job with `permissions: id-token: write` asks GitHub for a signed token.
2. `aws-actions/configure-aws-credentials` calls `sts:AssumeRoleWithWebIdentity` with that token and the role in `vars.AWS_ROLE_ARN`.
3. AWS validates the token against the OIDC provider and the role's trust policy, and returns credentials valid for one hour.

## Trust policy

Defined in `bootstrap/main.tf`. The role can be assumed only if:

- `token.actions.githubusercontent.com:aud` = `sts.amazonaws.com`, and
- `token.actions.githubusercontent.com:sub` = `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/<branch>`

The subject is customised to include the **numeric** owner and repository IDs, so a deleted-and-recreated or transferred repository with the same name cannot assume the role. Only the configured branch (normally `main`) can deploy; pull-request and other-branch workflows cannot assume it.

> The numeric-ID subject requires the repository's OIDC subject-claim template to include IDs (GitHub: *Settings -> Actions -> General*, or the API). This repository is configured that way.

## The CI role's permissions

Attached policy: `<role>-policy` (`bootstrap/ci-policy.tf`). It replaced `AdministratorAccess` in v1.0 and was derived from CloudTrail evidence of what Terraform and the deploy scripts actually call. Summary:

| Area | Grant |
|---|---|
| Terraform state | List the bucket; Get/Put/Delete objects under `<project_name>/*` only |
| EC2 | Describe; create instances, security groups and addresses in the configured region; manage (start/stop/terminate/modify/tag) only resources tagged `project=<project_name>`; tag only on create |
| IAM | Create/update/delete only the role and instance profile named `<project_name>-ec2`; attach only `AmazonEC2ContainerRegistryReadOnly` and `AmazonSSMManagedInstanceCore`; `iam:PassRole` only to `ec2.amazonaws.com` |
| ECR | Manage only the repository `<project_name>`; push/pull its images; `GetAuthorizationToken` |
| SSM | `SendCommand` with `AWS-RunShellScript` only against instances tagged `project=<project_name>`; read command results |

Verified denials: reading the bootstrap state, attaching `AdministratorAccess` to the instance role, and creating an S3 bucket.

## Setting it up

After the bootstrap apply:

```bash
gh variable set AWS_ROLE_ARN --body "$(cd bootstrap && terraform output -raw github_actions_role_arn)"
gh variable set AWS_REGION   --body "<region>"
```

These are **variables**, not secrets: the role ARN is not sensitive and the trust policy is what protects it.

## Adding a permission

1. Reproduce the failure and read the `AccessDenied` message / CloudTrail event.
2. Add the narrowest action and resource to `bootstrap/ci-policy.tf`.
3. Apply `bootstrap/` with admin credentials and re-run the pipeline.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Wrong branch, wrong repository, owner/repo ID mismatch, or `AWS_ROLE_ARN` points to another role |
| `AccessDenied` on a Terraform action | The scoped policy lacks the action; see "Adding a permission" |
| Role assumed but state read fails | `backend.hcl` key is outside `<project_name>/` |
