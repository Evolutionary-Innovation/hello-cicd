# Deployment Guide

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `pipeline.yml` | push to `main` (not docs-only), manual | Runs the three stages below in order |
| `infrastructure.yml` | called by Pipeline, manual | fmt check, init, validate, plan, apply the saved plan |
| `build-image.yml` | called by Pipeline, manual | Builds `src/` and pushes `<ecr>:<git sha>`; skips if that tag already exists (tags are immutable) |
| `deploy-app.yml` | called by Pipeline, manual (`image_tag` input) | Deploys an image to the instance and gates on health |

Stages are chained with `needs:`: build never races infrastructure, deploy never races build. The Pipeline workflow has a serialised concurrency group, so overlapping pushes queue.

## What a deploy does

1. **Assume the CI role** through OIDC and read Terraform outputs (`instance_id`, `ecr_repository_url`, `container_name`, `app_port`, `public_ip`).
2. **Wait for the instance** (`wait-for-instance.sh`): until it is `Online` in SSM (up to 10 min) and `cloud-init` has finished, so a freshly rebuilt instance is safe to use.
3. **Record the previous image**: the image the running container was created from (empty on first deploy).
4. **Deploy** (`remote/deploy.sh` via SSM): ECR login on the instance, `docker pull`, remove the old container, `docker run -d --restart unless-stopped -e PORT -p PORT:PORT`.
5. **Health check**: polls `http://<public_ip>:<port>/health` every 5 s for 90 s, requiring `{"status":"ok","sha":"<deployed tag>"}`.
6. **Roll back** if step 4 or 5 failed, see [Rollback](rollback.md).

The deployed container always restarts after an instance reboot (`--restart unless-stopped`).

## Everyday use

```bash
git push origin main
```

Watch the Actions tab. Docs and Markdown-only changes are ignored by the pipeline.

Manual runs (Actions -> workflow -> *Run workflow*): useful to re-run Infrastructure alone, or to deploy a specific SHA with *Deploy Application* (`image_tag`).

## Application contract

The application in `src/` must:

- listen on `$PORT` (set from `app_port`),
- expose `GET /health` as described in [Health checks](health-checks.md),
- build from `src/Dockerfile` with `ARG GIT_SHA` exposed as `ENV GIT_SHA`,
- run as a non-root user (the template image uses `USER node`).

## Instance changes

Instance bootstrap is `user_data` in `terraform/main.tf` (installs Docker and the SSM agent). Editing it does not re-run on an existing instance; apply `-replace=aws_instance.web` (see [Terraform](terraform.md)).

## Deployment behaviour to know

- A deploy stops the old container before the new one starts, so there is a short interruption per deploy (single instance, no blue/green).
- The host keeps pulled images; there is no host-side pruning in v1.0 (see [Known limitations](releases/v1.0.md)).
- The ECR lifecycle policy keeps the 10 most recent tagged images and expires untagged ones after a day; that bounds how far back a manual rollback can go.
