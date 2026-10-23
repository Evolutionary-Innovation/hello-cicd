# terraform-aws-cicd-template: AWS Terraform CI/CD Platform

A reusable, template-ready platform that takes a containerised web application from `git push` to a running, health-checked deployment on AWS, with no long-lived credentials, no SSH and no AWS Console steps.

It is a **template**, not a deployment. It ships with placeholder values (`my-project`, `REPLACE-ME-*`) and a manual-only Pipeline, so it deploys nothing and refers to no real account, repository or state bucket. To start a project: copy it, run one script to configure it, bootstrap the AWS account, replace `src/` with the real application.

## What it does

Once a project is configured (the configure script enables the push trigger), every push to `main` runs GitHub Actions:

1. **Infrastructure** - runs `terraform plan` and applies the saved plan: EC2 instance, Elastic IP, security group, ECR repository, instance IAM role.
2. **Build** - builds `src/Dockerfile` and pushes an immutable image tagged with the git SHA to ECR.
3. **Deploy** - tells the instance, through AWS Systems Manager (SSM), to pull and run that image, then waits for `/health` to report the new SHA. If it does not, the previous image is restored automatically.

## How it works

```
 git push main
      |
      v
 GitHub Actions --OIDC--> scoped IAM role (no stored keys)
      |
      +--> terraform (S3 state, native locking) --> EC2, EIP, SG, ECR, instance role
      +--> docker build/push ---------------------> ECR  (<repo>:<git sha>, immutable)
      +--> SSM Run Command -----------------------> EC2 (docker pull / run, rollback)
      +--> curl http://<eip>:<port>/health --------> {"status":"ok","sha":"<git sha>"}
```

- Two Terraform stacks. `bootstrap/` (applied by a human with admin credentials) owns the state bucket, the GitHub OIDC provider and the CI role. `terraform/` (applied by CI) owns the application infrastructure. CI can never change its own permissions.
- Everything is named from one variable, `project_name`, and tagged `project`, `environment`, `managed-by`. The CI role's permissions are scoped to that name and tag.
- Deployment uses SSM, so port 22 is closed, there is no key pair and there are no deploy secrets.

Details: [Architecture](docs/architecture.md), [Security](docs/security.md).

## Quick start (in a project created from this template)

```bash
git push origin main            # triggers Pipeline: infrastructure -> build -> deploy
curl http://<public_ip>:3000/health
```

`public_ip` comes from `terraform output` in `terraform/` (needs read access to the state bucket). In the unconfigured template the Pipeline can only be started manually (`workflow_dispatch`) and will fail until bootstrap is done.

## Bootstrapping AWS

One-off per account/project, with admin credentials on your workstation. Short version:

```bash
cd bootstrap
mv backend.tf backend.tf.off && terraform init && terraform apply     # local state creates the bucket
mv backend.tf.off backend.tf && terraform init -migrate-state -backend-config=backend.hcl -force-copy
terraform output github_actions_role_arn
```

Full procedure and gotchas: [Bootstrap Guide](docs/bootstrap.md).

## Configuring GitHub

Two repository **variables** (not secrets) are all CI needs:

```bash
gh variable set AWS_REGION   --body "eu-west-2"
gh variable set AWS_ROLE_ARN --body "$(cd bootstrap && terraform output -raw github_actions_role_arn)"
```

No secrets are required. See [OIDC Guide](docs/oidc.md).

## Deploying

In a configured project, push to `main`. Docs-only pushes (`docs/**`, `**/*.md`) do not trigger the pipeline. Individual stages can be run from the Actions tab (Infrastructure, Build Image, Deploy Application). See [Deployment Guide](docs/deployment.md).

## Rollback

- **Automatic**: the deploy job records the running image first. If the new container fails to start or `/health` does not report `ok` and the new SHA within 90 s, it redeploys the previous image and verifies it.
- **Manual**: run *Deploy Application* with `image_tag` set to an older commit SHA (the last 10 tagged images are kept), or `git revert` and push.

See [Rollback Guide](docs/rollback.md).

## Health checks

The app must expose `GET /health` returning HTTP 200 and `{"status":"ok","sha":"<GIT_SHA>"}`. The Dockerfile bakes the commit in as `GIT_SHA`. The deploy gate compares that SHA to the one it just deployed, so a stale container can never pass. See [Health Check Guide](docs/health-checks.md).

## Disaster recovery

All infrastructure is code; the only state that matters lives in the versioned S3 state bucket. A lost instance, a destroyed stack or a broken deploy is recovered by re-running the pipeline. This was proven by a full destroy and rebuild. See [Disaster Recovery](docs/disaster-recovery.md) and [Destroy / Rebuild](docs/destroy-rebuild.md).

## Creating a new project from the template

```bash
scripts/configure-project.sh --name my-app --owner my-org --repo my-repo \
    --state-bucket my-org-terraform-state --region eu-west-2
```

Then follow the checklist below and [New Project Guide](docs/new-project.md).

## Documentation

| Guide | Purpose |
|---|---|
| [Architecture](docs/architecture.md) | Components and data flow |
| [Bootstrap](docs/bootstrap.md) | Preparing an AWS account |
| [Terraform](docs/terraform.md) | Stacks, state, variables, plan gate |
| [OIDC](docs/oidc.md) | GitHub-to-AWS trust and the CI role |
| [Deployment](docs/deployment.md) | Pipeline stages and operation |
| [Rollback](docs/rollback.md) | Automatic and manual rollback |
| [Health checks](docs/health-checks.md) | The `/health` contract |
| [SSM](docs/ssm.md) | Remote execution without SSH |
| [Repository structure](docs/repository-structure.md) | What lives where |
| [Disaster recovery](docs/disaster-recovery.md) | Failure scenarios and recovery |
| [Security](docs/security.md) | Controls, boundaries, residual risk |
| [New project](docs/new-project.md) | Using this as a template |
| [Destroy / rebuild](docs/destroy-rebuild.md) | Tearing down and recreating |
| [Release](docs/release.md) | Versioning and tagging |
| [Roadmap](docs/roadmap.md) | What is next |
| [Review report](docs/review-report.md) | v1.0 repository review and remaining hard-coded values |
| [v1.0 release notes](docs/releases/v1.0.md) | Release notes, summaries, lessons, limitations |

## Isolation rules

Each project made from this template must be fully independent of every other one, including the template and other repositories you own:

- Unique `project_name` (it names the IAM role and policy, instance role, security group, ECR repository and state key).
- A state bucket you own, ideally per account; never reuse another project's key.
- Its own GitHub owner/repo IDs in the OIDC trust (the script looks them up).
- Do not copy another project's `terraform.tfvars` or `backend.hcl`.
- The GitHub OIDC provider is one per AWS account; see the import note in [Bootstrap](docs/bootstrap.md).

# Template Migration Checklist

Work through these in order for a new project.

1. **Clone repository** - `git clone <this repo> <new-project>`; remove the old history if you want a clean start (`rm -rf .git && git init`).
2. **Rename project** - run `scripts/configure-project.sh --name <name> --owner <org> --repo <repo> --state-bucket <bucket> --region <region> [--env dev]`. It rewrites both `terraform.tfvars` and both `backend.hcl`, gives the bootstrap state its own key (`bootstrap/<name>/terraform.tfstate`), enables the Pipeline push trigger, and drops any role-name override so the CI role becomes `<name>-github-actions`.
3. **Create GitHub repository** - create the empty repository under the owner given above (same name as `--repo`); add it as `origin`. The script reads the numeric owner/repo IDs from the public API; for a private repository pass `--owner-id` and `--repo-id`.
4. **Configure bootstrap** - review `bootstrap/terraform.tfvars`: `state_bucket_name` must be globally unique, `github_branch` is the only branch allowed to deploy.
5. **Configure AWS** - admin credentials in your shell (`aws sts get-caller-identity` shows the right account). If this account already has the GitHub OIDC provider, see the import note in [Bootstrap](docs/bootstrap.md).
6. **Apply bootstrap stack** - follow [Bootstrap](docs/bootstrap.md). Review the plan; it should only create resources.
7. **Apply infrastructure** - push to `main` after GitHub is configured, or apply locally once (`cd terraform && terraform init -backend-config=backend.hcl && terraform apply`).
8. **Configure GitHub** - set the `AWS_REGION` and `AWS_ROLE_ARN` repository variables. No secrets.
9. **Replace application code** - replace `src/`. Keep: the `Dockerfile` (listens on `$PORT`, takes `GIT_SHA`) and the `/health` contract.
10. **Verify CI/CD** - the Pipeline run is green (infrastructure, build, deploy).
11. **Verify deployment** - `curl http://<public_ip>:<port>/health` returns `ok` and the commit SHA you pushed.
12. **Verify rollback** - once, push a change that breaks `/health`; the run must fail and the site must keep serving the previous SHA. Revert afterwards.
13. **Verify rebuild** - once, `terraform destroy` in `terraform/` and push; the pipeline recreates everything. See [Destroy / rebuild](docs/destroy-rebuild.md).
14. **Security review** - work through [Security](docs/security.md): branch protection on `main`, the open port, TLS, who has admin to the AWS account.
15. **Release process** - tag `v1.0` following [Release](docs/release.md).

# Definition Of Done

A migration is complete when all of the following are true:

- [ ] `grep -r "<old project name>"` over the repository (excluding `.git`) returns nothing.
- [ ] `terraform plan` in both stacks reports no changes.
- [ ] The Pipeline run on `main` is green and `/health` reports the deployed commit SHA.
- [ ] The CI role has only the project-scoped policy (no `AdministratorAccess`), and no AWS access keys or deploy secrets exist in GitHub.
- [ ] Port 22 is closed, the instance has no key pair, and it is `Online` in SSM.
- [ ] A deliberately broken deploy was rolled back automatically, and the break was reverted.
- [ ] A destroy and rebuild of the `terraform/` stack succeeded through the pipeline.
- [ ] Branch protection is enabled on `main` and the security review is signed off.
- [ ] The release is tagged and the notes list the project's known limitations.
