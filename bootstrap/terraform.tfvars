# TEMPLATE DEFAULTS - placeholders only. Run scripts/configure-project.sh to set real values.
# Nothing here refers to any real project, account, repository or state bucket.
project_name      = "my-project"
environment       = "dev"
aws_region        = "eu-west-2"
state_bucket_name = "REPLACE-ME-globally-unique-state-bucket"

# github_role_name is optional. Unset, the CI role is "<project_name>-github-actions".

github_owner    = "REPLACE-ME-owner"
github_owner_id = 0
github_repo     = "REPLACE-ME-repo"
github_repo_id  = 0
github_branch   = "main"
