#!/usr/bin/env bash
# Run a script on an EC2 instance through SSM Run Command and wait for the result.
#
#   usage: ssm-run.sh <instance-id> [arg ...] < script
#
# The script (stdin) runs as root on the instance with the args as $1, $2, ...
# Remote stdout goes to stdout; remote stderr and progress go to stderr.
# Exits 0 only if the remote command succeeded.
set -euo pipefail

INSTANCE_ID="$1"; shift
TIMEOUT="${SSM_TIMEOUT:-300}"

ARGS=""
for a in "$@"; do ARGS+=" $(printf '%q' "$a")"; done

BODY="#!/bin/bash
export HOME=/root
set -euo pipefail
set --$ARGS
$(cat)"

CMD_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --comment "github-actions run ${GITHUB_RUN_ID:-local}" \
  --parameters "$(jq -cn --arg c "$BODY" --arg t "$TIMEOUT" '{commands: [$c], executionTimeout: [$t]}')" \
  --query Command.CommandId --output text)"
echo "SSM command $CMD_ID sent to $INSTANCE_ID" >&2

deadline=$((SECONDS + TIMEOUT + 60))
while :; do
  STATUS="$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
    --query Status --output text 2>/dev/null || echo Pending)"
  case "$STATUS" in Success|Failed|Cancelled|TimedOut) break ;; esac
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "::error::SSM command $CMD_ID still $STATUS after $((TIMEOUT + 60))s" >&2
    exit 1
  fi
  sleep 3
done

INV="$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --output json)"
jq -r .StandardOutputContent <<<"$INV"
jq -r .StandardErrorContent <<<"$INV" >&2
echo "SSM command $CMD_ID finished: $STATUS" >&2
[ "$STATUS" = Success ]
