# Architecture

## Repository layout

```
repo
├── src/          Application (Node/Express) and its Dockerfile
├── terraform/    Main stack: EC2, security group, Elastic IP, key pair, ECR, EC2 IAM role/profile
├── bootstrap/    Bootstrap stack: state bucket, GitHub OIDC provider, GitHub Actions role
├── keys/public/  Public half of the EC2 SSH key pair
├── .github/      Workflows and the terraform-outputs composite action
└── docs/
```

## Delivery pipeline

`pipeline.yml` runs on every push to `main` (or manually) and chains the stages:

```
Infrastructure (terraform apply) -> Build Image (push to ECR) -> Deploy (ssh, docker pull, docker run)
```

- Each stage is also runnable on its own via `workflow_dispatch`.
- Stages are gated with `needs:`, so build never races infrastructure and deploy never races build.
- The pipeline has a serialised concurrency group; overlapping pushes queue.
- GitHub authenticates to AWS with OIDC (`AWS_ROLE_ARN`); no AWS keys are stored.
- The only remaining secret is `EC2_SSH_KEY`, used by the deploy step.

## Configuration

Terraform is the single source of truth.

- `terraform/terraform.tfvars` and `bootstrap/terraform.tfvars` hold non-secret values.
  Only `*.secret.tfvars` files are git-ignored.
- Build and deploy read Terraform outputs through `.github/actions/terraform-outputs`,
  which exports each output as an upper-cased env var (`ecr_repository_url` -> `ECR_REPOSITORY_URL`).
- GitHub Variables needed before Terraform can be read: `AWS_ROLE_ARN`, `AWS_REGION`.
- Backend blocks cannot use variables; `backend.tf` in each stack must be kept in sync
  with `state_bucket_name` and `aws_region` by hand.

## Stacks

| Stack | State key | Applied by |
|---|---|---|
| `bootstrap/` | `bootstrap/terraform.tfstate` | Manually, with admin credentials (CI never modifies its own access) |
| `terraform/` | `hello-cicd/terraform.tfstate` | The Infrastructure workflow |

Both use S3 native state locking (`use_lockfile`). See `bootstrap/README.md` for
bringing up a fresh account.
