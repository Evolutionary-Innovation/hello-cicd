# Security Guide

## Controls in place (v1.0)

### Identity and access
- **No long-lived credentials.** GitHub assumes an IAM role through OIDC; the trust policy pins the audience, the numeric owner and repository IDs, and a single branch.
- **Least-privilege CI role.** `AdministratorAccess` was removed. The customer-managed policy is scoped by resource name, by `project` tag, by region and by an `iam:PolicyARN` allow-list. Details in the [OIDC Guide](oidc.md).
- **CI cannot widen its own access.** The role, policy, OIDC provider and state bucket belong to the bootstrap stack; CI has no access to the bootstrap state or to IAM beyond `<project_name>-ec2`.
- **Verified negative tests:** the scoped role is denied reading the bootstrap state, attaching `AdministratorAccess` to the instance role and creating an S3 bucket.
- **No deploy secrets.** The former `EC2_SSH_KEY` is no longer used.

### Network and host
- **Port 22 closed, no key pair.** Access and deploys use SSM.
- **Single ingress rule:** the application port.
- **IMDSv2 required**, hop limit 1 (a container cannot reach instance credentials through a proxy hop).
- **Encrypted root volume** (EBS default key).
- **Instance role** is limited to ECR read-only and SSM core.
- Application container runs as a **non-root user**; Docker restart policy `unless-stopped`.

### Supply chain and delivery
- **Immutable ECR tags** (SHA) with scan-on-push; lifecycle policy limits retained images.
- Every deployment is traceable to a commit through `/health`.
- Terraform applies the exact saved plan; `fmt` and `validate` run first.
- State bucket: versioned, encrypted (SSE-S3), public access blocked, `prevent_destroy`, native locking.

## Residual risks and recommended actions

| Risk | Severity | Recommendation |
|---|---|---|
| Anything that can push to `main` can deploy and runs as the CI role (root on the instance via SSM) | High | Enable branch protection on `main`: require pull requests and review; restrict who can push |
| No TLS; app port open to `0.0.0.0/0` over HTTP | Medium | Put CloudFront or an ALB with ACM in front; restrict the SG to it (roadmap) |
| Actions pinned by tag (`@v4`), not by commit SHA | Medium | Pin by SHA and use Dependabot for actions |
| Workflow files on `main` define what the role does | Medium | Use CODEOWNERS for `.github/` and `bootstrap/` |
| Scan results not enforced | Low | Add a gate on ECR scan findings |
| EBS encrypted with the AWS-managed key, state with SSE-S3 | Low | Move to customer-managed KMS if compliance requires |
| No monitoring, alarms or alerting | Medium | CloudWatch alarms on instance/health (roadmap) |
| Admin credentials used for bootstrap are outside the platform | Medium | Use SSO with short sessions and MFA; do not keep admin access keys |
| Public repository exposes account ID and resource names in committed tfvars/docs | Low | Accepted: they are identifiers, not secrets. Use a private repository if undesired |
| Host Docker images are never pruned | Low | Disk fills over time; replace the instance periodically or add pruning |
| Single instance/AZ | Availability | See roadmap |

## Security review checklist (per project)

- [ ] Branch protection on `main`; CODEOWNERS for `.github/**`, `bootstrap/**`
- [ ] `grep` the repository for AWS keys and tokens; none should exist
- [ ] CI role has only `<role>-policy` attached (`aws iam list-attached-role-policies`)
- [ ] `aws ec2 describe-security-groups` shows only the app port open; no key pair on the instance
- [ ] Instance `Online` in SSM; IMDSv2 `required`; volume encrypted
- [ ] No unused GitHub secrets or variables (old `EC2_SSH_KEY`, `ECR_REPOSITORY`)
- [ ] Decision recorded on TLS and public exposure
- [ ] Admin access to the account reviewed (MFA/SSO)

## Reporting

Treat any suspected credential exposure as an incident: rotate/disable, check CloudTrail for the CI role and admin users, then rebuild if the instance may be compromised (it is disposable).
