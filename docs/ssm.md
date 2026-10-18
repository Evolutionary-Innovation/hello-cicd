# SSM Guide

AWS Systems Manager (SSM) Run Command is how CI runs commands on the instance. It replaces SSH: there is no key pair, no port 22 and no secret.

## Requirements

- Instance profile with `AmazonSSMManagedInstanceCore` (created by `terraform/create-iam.tf`).
- `amazon-ssm-agent` on the instance. The standard Amazon Linux 2023 AMI includes it, and `user_data` also installs and enables it idempotently. (The *minimal* AL2023 AMI does not; the AMI filter in `terraform/main.tf` excludes it.)
- Outbound HTTPS from the instance (the security group allows all egress; the default VPC has an internet gateway).
- CI role permission to call `ssm:SendCommand` on `AWS-RunShellScript` and on instances tagged `project=<project_name>`.

## How CI uses it

`.github/scripts/ssm-run.sh <instance-id> [args...] < script`:

1. Builds a script body: `set -euo pipefail`, positional args from the arguments, then the script read from stdin.
2. Sends it with `aws ssm send-command` (document `AWS-RunShellScript`, execution timeout 300 s).
3. Polls `get-command-invocation` until it finishes, prints remote stdout to stdout and remote stderr to stderr.
4. Exits non-zero unless the status is `Success`.

Remote scripts live in `.github/scripts/remote/`:

| Script | Args | Purpose |
|---|---|---|
| `wait-bootstrap.sh` | - | Waits for cloud-init to finish and checks Docker |
| `current-image.sh` | container | Prints the image the container was created from |
| `deploy.sh` | image, container, port, region | ECR login, pull, replace container |
| `rollback.sh` | image, container, port, region | Same, skipping if already running |

`wait-for-instance.sh` first waits until the instance is `Online` in SSM, which matters after a rebuild.

## Using it by hand

With suitable AWS credentials:

```bash
# interactive shell (needs the Session Manager plugin and ssm:StartSession, which the CI role does not have)
aws ssm start-session --target <instance-id>

# one-off command
echo 'docker ps' | bash .github/scripts/ssm-run.sh <instance-id>

# is the agent registered?
aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
```

Commands are logged by SSM (list with `aws ssm list-commands`) and appear in CloudTrail.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Instance never `Online` | No `AmazonSSMManagedInstanceCore` on the role; agent not installed/running; no outbound internet; minimal AMI |
| `AccessDeniedException` on `SendCommand` | Instance not tagged `project=<project_name>`, or the document is not `AWS-RunShellScript` |
| Command `Failed` | Read stderr in the job log; the script runs as root with `set -euo pipefail` |
| Command `TimedOut` | Raise `SSM_TIMEOUT` for the step; check Docker/ECR connectivity |
| `Wait For Instance` fails with cloud-init errors | Read `/var/log/user-data.log` (shown in the job output) |

## Security notes

Anyone who can `SendCommand` has root on the instance. That is why the CI role is limited to tagged instances, to one document, and to a single branch of one repository (see [Security](security.md)).
