# Rollback Guide

## Automatic rollback

Implemented in `deploy-app.yml`:

1. Before deploying, the job reads the image the running container was created from (`remote/current-image.sh`) and stores it as `PREV`.
2. If the *Deploy Container* step or the *Health Check* step fails, the *Roll Back* step runs (only when `PREV` is non-empty).
3. `remote/rollback.sh` redeploys `PREV` through SSM (a no-op if it is already running).
4. The job polls `/health` until it reports `ok` and the previous SHA, and writes a note to the run summary.
5. The workflow run is still **failed** - rollback restores service, it does not hide the failed release.

If the previous image predates the `/health` endpoint, a `200` on `/` is accepted.

### Evidence

Validated on 2026-10-18 by pushing a commit that made `/health` return 500 (`ab19d71`). The pipeline built and deployed it, the health gate failed, and the instance was automatically redeployed to the previous good image (`20ff5db`); the site continued to report `20ff5db`. The test commit was then reverted.

## Manual rollback

Option A - redeploy an older image (fast, no rebuild):

1. Actions -> *Deploy Application* -> *Run workflow* on `main`.
2. `image_tag` = the full git SHA of the version you want.
3. The same health gate applies.

Only the last 10 tagged images are retained in ECR. Check what is available:

```bash
aws ecr describe-images --repository-name <project_name> \
  --query 'sort_by(imageDetails,&imagePushedAt)[].[imageTags[0],imagePushedAt]' --output text
```

Option B - revert in git (preferred for a lasting fix):

```bash
git revert <bad commit>
git push origin main
```

The pipeline builds and deploys the reverted code like any other change.

## What rollback does not cover

- **Infrastructure changes**: Terraform is not rolled back by the deploy job. Revert the Terraform change in git and push.
- **Data**: the platform has no data store; if the application adds one, schema migrations need their own rollback plan.
- **A broken first deploy** (no previous image): nothing to roll back to; fix forward.
- **Instance down**: rollback needs SSM. If the instance is unreachable, see [Disaster recovery](disaster-recovery.md).
