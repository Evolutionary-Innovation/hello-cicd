# Bootstrap stack

Owns what the main stack depends on: the Terraform state bucket and the
GitHub Actions OIDC provider/role. Apply manually with admin credentials;
CI does not run this stack, so it can never modify its own access.

State is stored in the state bucket under `bootstrap/terraform.tfstate`.

## Fresh account

1. Comment out `backend.tf`, then `terraform init && terraform apply` (local state).
2. Restore `backend.tf`, then `terraform init -migrate-state`.
3. Set the GitHub variable `AWS_ROLE_ARN` to the `github_actions_role_arn` output.
4. Run the main stack in `../terraform`.
