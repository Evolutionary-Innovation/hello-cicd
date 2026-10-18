#!/usr/bin/env bash
# Point this template at a new project. Rewrites the non-secret values in
#   bootstrap/terraform.tfvars, bootstrap/backend.hcl,
#   terraform/terraform.tfvars, terraform/backend.hcl
#
#   scripts/configure-project.sh --name stablebuddy --owner my-org --repo stablebuddy \
#       --state-bucket my-org-terraform-state --region eu-west-2 [--env dev] [--branch main]
#
# Numeric GitHub owner/repo IDs are looked up from the public GitHub API unless
# --owner-id / --repo-id are given (needed for private repositories).
# The legacy github_role_name override is removed so the role becomes
# "<name>-github-actions"; pass --keep-role-name to leave it untouched.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME=""; ENVIRONMENT="dev"; REGION=""; BUCKET=""; OWNER=""; REPO=""; BRANCH="main"
OWNER_ID=""; REPO_ID=""; KEEP_ROLE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --state-bucket) BUCKET="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --owner-id) OWNER_ID="$2"; shift 2 ;;
    --repo-id) REPO_ID="$2"; shift 2 ;;
    --keep-role-name) KEEP_ROLE=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for v in NAME REGION BUCKET OWNER REPO; do
  [ -n "${!v}" ] || { echo "missing --$(echo "$v" | tr 'A-Z_' 'a-z-' | sed 's/^bucket$/state-bucket/')" >&2; exit 2; }
done
[[ "$NAME" =~ ^[a-z][a-z0-9-]{1,30}$ ]] || { echo "--name must be lowercase letters, digits and hyphens (2-31 chars, starts with a letter)" >&2; exit 2; }

if [ -z "$OWNER_ID" ]; then
  OWNER_ID="$(curl -fsS "https://api.github.com/users/$OWNER" | jq -r .id)"
fi
if [ -z "$REPO_ID" ]; then
  REPO_ID="$(curl -fsS "https://api.github.com/repos/$OWNER/$REPO" | jq -r .id)"
fi

# set_var <file> <key> <value> : replace "key = ..." (strings are quoted, numbers/bools are not)
set_var() {
  local file="$1" key="$2" value="$3" rendered
  if [[ "$value" =~ ^[0-9]+$ || "$value" == true || "$value" == false ]]; then rendered="$value"; else rendered="\"$value\""; fi
  grep -qE "^$key[[:space:]]*=" "$file" || { echo "$file has no '$key' line" >&2; exit 1; }
  sed -i -E "s|^($key[[:space:]]*=[[:space:]]*).*|\1$rendered|" "$file"
}

B=bootstrap/terraform.tfvars
set_var $B project_name "$NAME"
set_var $B environment "$ENVIRONMENT"
set_var $B aws_region "$REGION"
set_var $B state_bucket_name "$BUCKET"
set_var $B github_owner "$OWNER"
set_var $B github_owner_id "$OWNER_ID"
set_var $B github_repo "$REPO"
set_var $B github_repo_id "$REPO_ID"
set_var $B github_branch "$BRANCH"
if [ "$KEEP_ROLE" -eq 0 ]; then
  sed -i -E '/^# Existing role kept by name/d; /^# Remove this line for new projects/d; /^github_role_name[[:space:]]*=/d' $B
fi

T=terraform/terraform.tfvars
set_var $T project_name "$NAME"
set_var $T environment "$ENVIRONMENT"
set_var $T aws_region "$REGION"

printf 'bucket = "%s"\nkey    = "bootstrap/terraform.tfstate"\nregion = "%s"\n' "$BUCKET" "$REGION" > bootstrap/backend.hcl
printf 'bucket = "%s"\nkey    = "%s/terraform.tfstate"\nregion = "%s"\n' "$BUCKET" "$NAME" "$REGION" > terraform/backend.hcl

echo "Configured '$NAME' ($ENVIRONMENT) in $REGION, state bucket $BUCKET, repo $OWNER/$REPO ($BRANCH)."
echo "Next: set GitHub variable AWS_REGION=$REGION, bootstrap the account, then set AWS_ROLE_ARN."
echo "See docs/new-project.md"
