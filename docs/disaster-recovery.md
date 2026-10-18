# Disaster Recovery

## What matters, and where it lives

| Asset | Location | Recoverable from |
|---|---|---|
| Infrastructure definition | Git | GitHub (and any clone) |
| Terraform state | Versioned S3 bucket | Previous object versions; or re-import |
| Application source and image recipe | Git | GitHub |
| Container images | ECR | Rebuilt from git (build skips only if the tag exists) |
| CI trust and permissions | Bootstrap stack | `terraform apply` in `bootstrap/` |
| Secrets | None stored | - |
| Application data | None (stateless) | Not applicable; add backups if the app adds a store |

The instance is disposable. Recovery is "run the pipeline again".

## Scenarios

### Broken deploy
Automatic rollback restores the previous image. If that fails, run *Deploy Application* with a known-good `image_tag`, or revert in git. See [Rollback](rollback.md).

### Instance unhealthy or lost (terminated, disk failure, unreachable)
```bash
cd terraform
terraform init -reconfigure -backend-config=backend.hcl
terraform apply -replace=aws_instance.web      # or simply push to main if Terraform already sees it missing
```
Then run the pipeline / *Deploy Application*. The EIP re-associates, so the public IP does not change. Expect 3-5 minutes (boot, `dnf update`, SSM registration).

### Entire main stack destroyed
Run the Infrastructure workflow (push, or manual). Terraform recreates everything; the pipeline then builds and deploys. The EIP is new, so any DNS pointing at it must be updated. Proven end to end: see [Destroy / rebuild](destroy-rebuild.md).

### ECR repository deleted or images lost
Terraform recreates the repository; Build re-pushes the image for the current commit (the "already in ECR" shortcut no longer applies). Older SHAs are gone, so rollback targets are only what you rebuild by re-running *Build Image* from those commits.

### State corrupted or deleted
The bucket is versioned: restore a previous version of `<project_name>/terraform.tfstate` (`aws s3api list-object-versions`, `copy-object` with `--copy-source ...?versionId=`). If no version is usable, `terraform import` each resource into a fresh state (the resource addresses are listed in `terraform/main.tf` and `terraform/create-iam.tf`) - or destroy the leftovers by tag `project=<project_name>` and rebuild.

### State lock stuck
Native locking uses `<key>.tflock` in the bucket. After confirming no run is active, `terraform force-unlock <lock-id>`.

### CI role or OIDC provider lost / broken
Apply `bootstrap/` with admin credentials. CI cannot repair its own access; this is intentional. Update `AWS_ROLE_ARN` if the ARN changed.

### State bucket lost
Recreate with `bootstrap/` (fresh-account procedure) and then re-import or rebuild the main stack. Treat as a last resort; the bucket has versioning and `prevent_destroy`.

### GitHub unavailable
Nothing deploys, but the running application is unaffected. With admin AWS credentials, `terraform apply` can be run locally and images built/pushed from a workstation, then deployed with `ssm-run.sh`.

### AWS region outage
Out of scope for v1.0 (single region, single instance, single AZ). To recover elsewhere: run `configure-project.sh` with another region, bootstrap, and push. See [Roadmap](roadmap.md).

## Recovery objectives (v1.0, indicative)

- RTO for a lost instance or full stack: roughly 10 minutes via the pipeline (measured rebuild: single pipeline run).
- RPO: no application data is held by the platform; configuration is as of the last commit.
