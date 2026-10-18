# Repository Structure

```
.
├── README.md                     Overview, quick start, Template Migration Checklist, Definition Of Done
├── .github/
│   ├── workflows/
│   │   ├── pipeline.yml          Entry point: infrastructure -> build -> deploy
│   │   ├── infrastructure.yml    Terraform fmt/init/validate/plan/apply (reusable)
│   │   ├── build-image.yml       Docker build and push to ECR (reusable)
│   │   └── deploy-app.yml        SSM deploy, health gate, rollback (reusable)
│   ├── actions/terraform-outputs/  Composite action: terraform outputs -> UPPER_CASE env vars
│   └── scripts/
│       ├── ssm-run.sh            Run a script on the instance via SSM and return its result
│       ├── wait-for-instance.sh  Wait for SSM registration and cloud-init
│       └── remote/               Scripts that run on the instance (deploy, rollback, current-image, wait-bootstrap)
├── bootstrap/                    Stack 1 - applied manually with admin credentials
│   ├── main.tf                   State bucket, OIDC provider, CI role + trust policy
│   ├── ci-policy.tf              Least-privilege CI policy and attachment
│   ├── variables.tf, terraform.tfvars, outputs.tf, providers.tf
│   └── backend.tf, backend.hcl   S3 backend (settings in backend.hcl)
├── terraform/                    Stack 2 - applied by CI
│   ├── main.tf                   EC2, AMI lookup, security group, EIP, ECR + lifecycle
│   ├── create-iam.tf             Instance role, policy attachments, instance profile
│   ├── variables.tf, terraform.tfvars, outputs.tf, providers.tf
│   └── backend.tf, backend.hcl
├── src/                          The application (replace for a new project)
│   ├── server.js, package.json, package-lock.json
│   ├── Dockerfile, .dockerignore
├── scripts/
│   └── configure-project.sh      Rename/reconfigure the template for a new project
└── docs/                         Guides, review report, release notes
```

## What to change per project

| Path | Change |
|---|---|
| `bootstrap/terraform.tfvars`, `terraform/terraform.tfvars`, both `backend.hcl` | Via `scripts/configure-project.sh` |
| `src/` | Your application (keep `/health` and `$PORT`) |
| `terraform/main.tf` | Instance size/shape, extra resources |
| `bootstrap/ci-policy.tf` | Only if you add AWS services the pipeline must manage |

## What should rarely change

`.github/` (workflows and scripts are project-agnostic: everything comes from Terraform outputs), `bootstrap/main.tf`, the Dockerfile's non-root and `GIT_SHA` conventions.

## Ignored files

`node_modules/`, `.terraform/`, `*.tfstate*`, `*.secret.tfvars`, `tfplan`, `keys/`, `*.pem`. Non-secret `terraform.tfvars` **is** committed by design.
