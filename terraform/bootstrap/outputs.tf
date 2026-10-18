output "github_actions_role_arn" {
  description = "Role assumed by GitHub Actions via OIDC (set as the AWS_ROLE_ARN GitHub variable)"
  value       = aws_iam_role.github_terraform.arn
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}
