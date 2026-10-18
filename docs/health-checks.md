# Health Check Guide

## The contract

The application must serve:

```
GET /health  ->  200  {"status":"ok","sha":"<commit sha>"}
```

In the template (`src/server.js`) the SHA comes from the `GIT_SHA` environment variable, which the Dockerfile sets from the `GIT_SHA` build argument. The build workflow passes the commit SHA, so the running image reports exactly the commit it was built from. `unknown` is returned if the image was built without the argument.

## How the deploy gate uses it

`deploy-app.yml`, step *Health Check*:

- polls `http://<public_ip>:<app_port>/health` every 5 seconds, up to 18 attempts (90 s),
- passes only when the response is `status == "ok"` **and** `sha` equals the tag just deployed,
- on failure prints the last 50 lines of the container's logs (via SSM) and fails the job, which triggers the rollback.

Checking the SHA, not only the status, prevents a false pass from the previous container still serving while the new one fails to start.

## Using it elsewhere

- **Rollback verification** uses the same endpoint and the previous tag.
- **Manual check**: `curl http://<public_ip>:3000/health`.
- **Operational use**: it also answers "which commit is live?".

## Writing a good `/health` for a real application

- Return quickly and do not depend on slow downstream calls; this is a liveness/version check for the deploy gate.
- If the app has critical dependencies (database), either include them in a separate `/ready` endpoint or accept that the deploy gate will fail when they are down.
- Keep the response small and free of secrets; the port is public.
- Never return `ok` while the process is shutting down or misconfigured.

## Limits

- The check runs from the GitHub runner over the public internet to the app port, so it also proves the security group and EIP are correct.
- There is no continuous monitoring or alarm after the deploy (see [Roadmap](roadmap.md)).
- No TLS in v1.0, so the check uses HTTP.
