# Destroy / Rebuild Guide

Use this to prove disaster recovery, to start over, or to patch the instance from scratch. Only the main stack (`terraform/`) is destroyed; the bootstrap stack, the state bucket and the OIDC role are never touched.

## Before you destroy: checklist

1. **Know what is lost.** The instance and its Docker images, the Elastic IP (the public IP changes), and all ECR images (`ecr_force_delete = true` lets Terraform delete a non-empty repository). Nothing else is stateful.
2. **Check the plan is exactly the resources you expect.** `terraform plan -destroy` and read the list; it must not include anything from `bootstrap/`.
3. **Check replacement-sensitive resources** ([Terraform Guide](terraform.md)): EIP, instance, ECR repository, instance role/profile.
4. **Have a rollback plan.** Everything is reproducible from the commit on `main`. If the rebuild fails: fix forward and re-run the pipeline; if a permission is missing, apply a fix to `bootstrap/` with admin credentials. The previous Terraform state is recoverable from S3 object versions.
5. **Tell consumers.** Anything pointing at the old EIP (DNS, firewalls, webhooks) must be updated afterwards.
6. **Do not push to `main` while the destroy is running**; the pipeline would try to recreate resources mid-destroy.

## Procedure

```bash
cd terraform
terraform init -reconfigure -backend-config=backend.hcl
terraform plan -destroy -out=destroy.tfplan       # review the list
terraform apply destroy.tfplan
terraform state list                              # empty

# local rebuild preview: should show only creates
terraform plan
```

Then trigger the pipeline (push to `main`, or run *Pipeline* manually):

1. **Infrastructure** creates the stack under the scoped CI role.
2. **Build** pushes the image (the repository is new, so it always builds).
3. **Deploy** waits for SSM and cloud-init on the new instance, deploys, and gates on `/health`.

Verify:

```bash
cd terraform
curl http://$(terraform output -raw public_ip):3000/health      # {"status":"ok","sha":"<head sha>"}
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
terraform plan -detailed-exitcode                               # exit 0: no drift
```

## Validated result (v1.0, 2026-10-18)

| Step | Result |
|---|---|
| `terraform plan -destroy` | 11 to destroy: ECR repo + lifecycle, EIP + association, instance, key pair, SG, instance role + 2 attachments + profile |
| Destroy | Complete in under a minute; state empty |
| Change set for rebuild | 10 creates, no key pair |
| Pipeline (scoped CI role, not admin) | Infrastructure, Build and Deploy all succeeded in one run |
| New instance | Standard AL2023 AMI, encrypted root volume, IMDSv2 required, no key pair, `Online` in SSM |
| `/health` | `ok`, reporting the commit SHA that was pushed |
| Drift | `terraform plan -detailed-exitcode` = 0 |
| Public IP | Changed (expected) |

## If something goes wrong

| Symptom | Action |
|---|---|
| Destroy fails on the security group | Instance still terminating; re-run apply of the destroy plan |
| Infrastructure job `AccessDenied` | Add the missing narrow permission to `bootstrap/ci-policy.tf` and apply `bootstrap/` with admin credentials; re-run |
| Deploy waits forever for SSM | See the [SSM Guide](ssm.md) troubleshooting table |
| ECR repository `RepositoryNotEmptyException` on destroy | `ecr_force_delete` is false; set to `true`, apply, then destroy |

## Replacing only the instance

```bash
terraform apply -replace=aws_instance.web
```

then run *Deploy Application*. The EIP, ECR repository and images are kept.
