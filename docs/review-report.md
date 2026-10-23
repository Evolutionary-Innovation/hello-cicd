# v1.0 Repository Review Report

Scope: every tracked file, reviewed for `hello-cicd` assumptions, hard-coded names and URLs, duplicated variables, obsolete outputs, dead code and workflows, stale documentation, temporary workarounds, unnecessary permissions and manual steps.

## Findings and actions

| # | Area | Finding | Action |
|---|---|---|---|
| 1 | Permissions | CI role held `AdministratorAccess` | **Fixed.** Replaced by a project-scoped customer-managed policy built from CloudTrail evidence and tested; admin attachment removed; temporary test role deleted |
| 2 | Permissions | `EC2_SSH_KEY` secret, key pair, port 22 | **Fixed.** Key pair resource and public key file removed; port 22 never open; secret unused (delete it in GitHub, see manual steps) |
| 3 | Naming | Resource names, ECR repository, container, tags tied to a literal | **Fixed.** All derive from `project_name`; tags `project`/`environment`/`managed-by`; ECR resources renamed `hello_cicd` -> `app` via `moved` blocks (removed after the rebuild) |
| 4 | Config | Backend bucket/key/region hard-coded in `backend.tf` | **Fixed.** Moved to `backend.hcl` per stack; `backend.tf` holds only `use_lockfile` |
| 5 | Config | Workflows depended on GitHub variables for ECR name, instance, port | **Fixed.** Everything comes from Terraform outputs through the composite action; only `AWS_ROLE_ARN` and `AWS_REGION` remain |
| 6 | Dead code | `aws_key_pair.deployer`, `key_name`, `keys/public/`, `public_dns` output, SSH deploy steps, bootstrap success marker in `/tmp` | **Removed** |
| 7 | Dead workflows | None found; the four workflows are all in use (three reusable + the entry point) | None |
| 8 | Temporary workaround | SSM agent installed ad hoc at deploy time on a minimal AMI | **Fixed.** Standard AL2023 AMI (agent included), `user_data` installs/enables it idempotently; `wait-for-instance.sh` waits for registration and cloud-init |
| 9 | Temporary workaround | `/tmp` marker for bootstrap completion (cleared on reboot) | **Fixed.** `cloud-init status --wait` |
| 10 | Stale docs | `docs/architecture.md` described SSH deploys; `bootstrap/README.md` was minimal | **Fixed.** Full documentation set; bootstrap README now points to the guide |
| 11 | Hardening | Root volume unencrypted; IMDSv1 allowed | **Fixed.** `encrypted = true`, `http_tokens = required`, hop limit 1 |
| 12 | Stability | `most_recent` AMI lookup would make CI replace the instance on an unrelated push when AWS publishes a new AMI | **Fixed.** `lifecycle { ignore_changes = [ami] }`; patch deliberately with `-replace` |
| 13 | Container | Image ran as root, no `.dockerignore`, no SHA in the image | **Fixed.** `USER node`, `.dockerignore`, `GIT_SHA` build arg, `/health` returns the SHA |
| 14 | CI noise | Docs commits re-ran the full pipeline | **Fixed.** `paths-ignore` for `docs/**` and `**/*.md` |
| 15 | Duplicated variables | `project_name`, `aws_region` in both stacks' tfvars and backend files | **Mitigated.** One script (`scripts/configure-project.sh`) writes all of them; they cannot be shared by Terraform across separate stacks |
| 16 | Obsolete outputs | `public_dns` | **Removed.** Remaining outputs are all consumed by workflows or humans |
| 17 | Cosmetic | `terraform/create-iam.tf` file name, bootstrap output without description | Left as is: no functional effect (per "no cosmetic micro-cleanups") |

## Verified behaviour after the cleanup

- Scoped CI role: Infrastructure (no-op plan), Build and Deploy green.
- Full destroy of the main stack and rebuild through the pipeline under the scoped role: green, `/health` reports the commit SHA, instance `Online` in SSM, no drift.
- Automatic rollback proven with a deliberately broken release (then reverted).

## Template separation (source level)

The committed configuration no longer describes a live project. `project_name` is `my-project`; owner, repo, owner ID, repo ID and state bucket are placeholders; the state keys are `my-project/terraform.tfstate` and `bootstrap/my-project/terraform.tfstate`; the legacy `github_role_name` override is gone; the Pipeline push trigger is commented out until `scripts/configure-project.sh` runs. Nothing in the repository refers to any other repository, AWS account or state file. This was a source-only change: no Terraform was executed and no AWS resource, state or OIDC trust was touched.

## Remaining hard-coded values that cannot yet be removed

| Value | Where | Why | Mitigation |
|---|---|---|---|
| State bucket name and region | `backend.hcl` (x2), `bootstrap/terraform.tfvars` | Backend blocks cannot use variables | Written together by `configure-project.sh` |
| `aws_region` | Both tfvars, backend.hcl, GitHub variable `AWS_REGION` | Needed before Terraform can run; GitHub variable cannot be set from Terraform without a PAT | Script prints the value to set; `gh variable set` |
| `AWS_ROLE_ARN` | GitHub variable | Only known after the bootstrap apply | Output `github_actions_role_arn`; one command |
| GitHub owner/repo IDs, branch | `bootstrap/terraform.tfvars` | The OIDC subject is pinned to them | Looked up by the script |
| Default VPC and subnet | `terraform/main.tf` (implicit) | Template targets a quick start; no VPC module | Roadmap: own VPC |
| `0.0.0.0/0` on the app port, HTTP only | Security group | No TLS front end yet | Roadmap: TLS and restricted SG |
| `instance_type`, `app_port`, `ecr_force_delete` | `terraform/terraform.tfvars` | Per-project choices, intentionally explicit | None needed |
| Root volume size 20 GB, ECR retention (10 tagged, 1 day untagged) | `terraform/main.tf` | Sensible defaults | Promote to variables when a project needs them |
| Action versions (`@v4`, `@v2`, `@v3`) | Workflows | Tag-pinned | Roadmap: pin by SHA |
| Public EIP changes on rebuild | - | Allocated by Terraform | Add DNS (roadmap) |
| `EXPOSE 3000` | `src/Dockerfile` | Informational only; the app listens on `$PORT` | None |

## Remaining manual steps (cannot be removed without extra privileges)

1. Admin applies `bootstrap/` (by design: CI must not manage its own access).
2. Set the `AWS_REGION` and `AWS_ROLE_ARN` GitHub variables.
3. Create the GitHub repository and enable branch protection.
4. Delete the unused GitHub secret `EC2_SSH_KEY` (and variable `ECR_REPOSITORY` if present).
5. Create the GitHub Release object from the tag (or `gh release create`).
