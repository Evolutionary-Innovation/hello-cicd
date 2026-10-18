# Architecture

## Components

| Component | Where | Purpose |
|---|---|---|
| State bucket | `bootstrap/` | Versioned, encrypted S3 bucket holding the state of both stacks (native locking, no DynamoDB) |
| GitHub OIDC provider and CI role | `bootstrap/` | Lets workflows from one repository and one branch assume a scoped IAM role |
| CI policy | `bootstrap/ci-policy.tf` | Least-privilege customer-managed policy attached to the CI role |
| EC2 instance | `terraform/` | Runs Docker; Amazon Linux 2023, encrypted gp3 root volume, IMDSv2 required, no key pair |
| Elastic IP | `terraform/` | Stable public address (changes only if the stack is rebuilt) |
| Security group | `terraform/` | One ingress rule: the application port; no SSH |
| ECR repository | `terraform/` | Immutable SHA tags, scan on push, lifecycle policy (untagged 1 day, keep 10 tagged) |
| Instance role and profile | `terraform/` | `AmazonSSMManagedInstanceCore` (SSM) and `AmazonEC2ContainerRegistryReadOnly` (pull) |
| Application | `src/` | Node/Express container exposing `/` and `/health` |

## Delivery pipeline

```
push to main
  -> Infrastructure  terraform fmt, init, validate, plan -out, apply tfplan
  -> Build Image     docker build ./src, push <ecr>:<sha> (skips if the tag already exists)
  -> Deploy          wait for SSM + cloud-init, record running image, deploy via SSM,
                     health gate on {status:ok, sha:<sha>}, roll back on failure
```

- Stages are reusable workflows (`workflow_call`) chained with `needs:` and also runnable alone (`workflow_dispatch`).
- `pipeline.yml` uses a serialised concurrency group: overlapping pushes queue and are never cancelled mid-apply.
- Docs-only pushes (`docs/**`, `**/*.md`) do not run the pipeline.

## Configuration flow

`project_name` is the single naming source. It drives the IAM role/profile, security group, EIP tag, ECR repository, container name, `project` tag, CI-policy scope and the state key.

Build and deploy read the Terraform outputs through `.github/actions/terraform-outputs`, which exports each output as an upper-case variable (`ecr_repository_url` -> `ECR_REPOSITORY_URL`). Adding an output makes it available to every job with no workflow change.

GitHub holds only `AWS_REGION` and `AWS_ROLE_ARN` (variables). Backend settings live in `backend.hcl` per stack because backend blocks cannot use variables.

## Trust boundaries

1. GitHub -> AWS: OIDC; subject pinned to owner ID, repo ID and branch.
2. CI role -> AWS: only the project's EC2/IAM/ECR/SSM resources and the project's state prefix.
3. CI -> instance: SSM Run Command only; the instance has no inbound path other than the app port.
4. Internet -> instance: TCP on the app port only.

## Design decisions

- **Two stacks** so the pipeline that applies infrastructure cannot widen its own permissions.
- **SSM instead of SSH** removes the key, the open port and the secret.
- **Immutable SHA tags** make every deployment and rollback traceable to a commit.
- **Plan-then-apply of the saved plan** guarantees CI applies exactly what was planned.
- **`ignore_changes = [ami]`** on the instance prevents an unrelated push from replacing the server when AWS publishes a new AMI.
