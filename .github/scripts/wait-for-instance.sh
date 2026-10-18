#!/usr/bin/env bash
# Usage: wait-for-instance.sh <instance-id>
# Blocks until the instance is Online in SSM and its user-data has finished.
# Needed after a rebuild, when deploy starts seconds after the instance is created.
set -euo pipefail

INSTANCE_ID="$1"
DEADLINE=$((SECONDS + ${SSM_ONLINE_TIMEOUT:-600}))

while :; do
  STATUS="$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)"
  if [ "$STATUS" = "Online" ]; then
    echo "$INSTANCE_ID is Online in SSM"
    break
  fi
  if [ "$SECONDS" -ge "$DEADLINE" ]; then
    echo "::error::$INSTANCE_ID did not become Online in SSM (last status: ${STATUS:-none})" >&2
    exit 1
  fi
  echo "waiting for SSM registration (status: ${STATUS:-none})"
  sleep 10
done

bash "$(dirname "$0")/ssm-run.sh" "$INSTANCE_ID" < "$(dirname "$0")/remote/wait-bootstrap.sh"
