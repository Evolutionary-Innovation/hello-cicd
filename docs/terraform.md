# Terraform Guide

## Stacks

| Stack | Directory | State key | Applied by | Contains |
|---|---|---|---|---|
| bootstrap | `bootstrap/` | `bootstrap/<project_name>/terraform.tfstate` | A human, admin credentials | State bucket, OIDC provider, CI role and policy |
| main | `terraform/` | `<project_name>/terraform.tfstate` | The Infrastructure workflow | EC2, EIP, security group, ECR, instance IAM role and profile |

Both pin `required_version >= 1.10` and `hashicorp/aws ~> 6.0`, and use S3 native locking (`use_lockfile = true`; no DynamoDB table).

## Configuration

- **Variables** live in committed `terraform.tfvars` files (non-secret). Only `*.secret.tfvars` are git-ignored. Variables have no defaults in the main stack, so a missing value fails loudly.
- **Backend** settings live in `backend.hcl` (bucket, key, region) because backend blocks cannot use variables. Always initialise with `terraform init -reconfigure -backend-config=backend.hcl`.
- **Tags**: `default_tags` apply `project`, `environment` and `managed-by` to everything. The CI policy relies on the `project` tag.

### Main stack variables

| Variable | Purpose |
|---|---|
| `project_name` | Naming source for every resource and the `project` tag |
| `environment` | Environment tag |
| `aws_region` | Deployment region |
| `instance_type` | EC2 size (`t3.micro`) |
| `app_port` | Container and security group port |
| `ecr_force_delete` | Lets `terraform destroy` remove a non-empty ECR repository |

### Outputs

`instance_id`, `public_ip`, `app_url`, `ecr_repository_url`, `ecr_repository_name`, `container_name`, `app_port`. Every output is exported to workflow jobs as an upper-case environment variable by `.github/actions/terraform-outputs`.

## The plan gate

CI never applies "whatever the config says now". It plans to a file and applies that file:

```
terraform fmt -check -recursive
terraform init -reconfigure -input=false -backend-config=backend.hcl
terraform validate
terraform plan -input=false -lock-timeout=60s -out=tfplan
terraform apply -input=false -auto-approve tfplan
```

When changing infrastructure, run the same plan locally first and check it. To list only real changes:

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.change.actions|join(",")) \(.address)"'
```

Stop and review if anything shows `delete,create` (replace) on the instance, role, instance profile, ECR repository, bucket or EIP.

## Replacement-sensitive resources

| Resource | Replaced by | Consequence |
|---|---|---|
| `aws_instance.web` | AMI (ignored by design), `user_data` edits, instance type families, root volume encryption | Downtime until the new instance deploys; EIP re-associates |
| `aws_eip.web` | Rare; destroy/rebuild | Public IP changes |
| `aws_ecr_repository.app` | Renaming `project_name` | All images lost; rebuilt by the next pipeline run |
| `aws_iam_role.ec2` / `aws_iam_instance_profile.ec2` | Renaming `project_name` | Instance must be re-created |
| State bucket (bootstrap) | Never; `prevent_destroy` | - |

Changing `project_name` in a live project renames everything: treat it as a rebuild.

## Deliberately patching the instance

The instance ignores AMI changes. To move to a newer AMI or re-run `user_data` from scratch:

```bash
cd terraform
terraform apply -replace=aws_instance.web
```

then let the pipeline redeploy the application (push, or run *Deploy Application*).

## Refactoring resources

Renaming a resource block would destroy and recreate it. Use a `moved` block (`moved { from = ..., to = ... }`) and delete it once all environments have applied it.
