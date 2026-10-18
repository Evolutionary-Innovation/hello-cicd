project_name      = "hello-cicd"
environment       = "dev"
aws_region        = "eu-west-2"
state_bucket_name = "ei-terraform-state-2026"

# Existing role kept by name so the AWS_ROLE_ARN GitHub variable stays valid.
# Remove this line for new projects to get "<project_name>-github-actions".
github_role_name = "github-terraform-role"

github_owner    = "Evolutionary-Innovation"
github_owner_id = 42237286
github_repo     = "hello-cicd"
github_repo_id  = 1423260544
github_branch   = "main"
