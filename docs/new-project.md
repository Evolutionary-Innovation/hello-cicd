# New Project Guide

How to start StableBuddy, RaceHorse, an engineering tool or a SaaS application from this template. The condensed checklist is in the [README](../README.md#template-migration-checklist); this guide adds the commands and decisions.

## 1. Decide

| Decision | Notes |
|---|---|
| `project_name` | Lowercase letters, digits, hyphens; 2-31 chars. Names the IAM role/profile, security group, ECR repository, container and state key |
| Environment | `dev`, `staging`, `prod`; tag only. Use a separate repository/state per environment, or a separate account |
| Region | One region per project |
| Account | A dedicated account per project is simplest. Sharing an account is supported; see the OIDC provider note in [Bootstrap](bootstrap.md) |
| State bucket | One per account is fine; each project writes under its own prefix (`<project_name>/...`, bootstrap under `bootstrap/<project_name>/...`) and the CI policy only grants the project prefix |
| Port | `app_port` in `terraform/terraform.tfvars` (default 3000) |

## 2. Create the project

```bash
git clone https://github.com/Evolutionary-Labs/terraform-aws-cicd-template <new-project> && cd <new-project>
rm -rf .git && git init -b main

scripts/configure-project.sh \
  --name <new-project> --env dev --region eu-west-2 \
  --state-bucket <unique-bucket-name> \
  --owner <github-owner> --repo <new-project>

git remote add origin https://github.com/<github-owner>/<new-project>.git
```

Create the (empty) GitHub repository first; the script reads its numeric ID from the GitHub API. For a private repository pass `--owner-id` and `--repo-id` (find them with `gh api repos/<owner>/<repo> --jq '.id, .owner.id'`).

## 3. Bootstrap AWS and GitHub

Follow [Bootstrap](bootstrap.md), then set `AWS_REGION` and `AWS_ROLE_ARN` as repository variables.

## 4. Replace the application

Replace `src/` with your application. Keep:

- `Dockerfile`: `ARG GIT_SHA` -> `ENV GIT_SHA`, non-root user, listens on `$PORT`
- `GET /health` returning `{"status":"ok","sha":"<GIT_SHA>"}`

If the application needs more AWS services (S3, a database, a queue), add them in `terraform/` and the matching narrow permissions in `bootstrap/ci-policy.tf`, applying `bootstrap/` before pushing.

## 5. First deployment

```bash
git add -A && git commit -m "Initial commit from template" && git push -u origin main
```

Before this push, bootstrap (step 3) must be applied and `AWS_ROLE_ARN` / `AWS_REGION` set: the configure script enabled the Pipeline push trigger.

Expect a green Pipeline run, then `curl http://<public_ip>:<port>/health`. The `public_ip` is in the Infrastructure job's Terraform outputs, or run `terraform output` in `terraform/`.

## 6. Prove it once

Run the verification steps of the checklist: rollback with a deliberately broken commit, a destroy/rebuild ([Destroy / rebuild](destroy-rebuild.md)), and the [security review](security.md). Then tag `v1.0` ([Release](release.md)).

## Values that still need a manual touch

See the final section of the [review report](review-report.md): GitHub repository variables, branch protection, DNS/TLS, default VPC assumption.

## Updating a project when the template improves

There is no automated sync. Compare with the template (`git remote add template ...; git diff template/main -- .github bootstrap terraform scripts`) and cherry-pick. Keep project-specific changes in `src/` and the tfvars so that diffs stay small.
