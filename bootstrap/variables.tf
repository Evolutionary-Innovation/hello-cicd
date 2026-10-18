variable "aws_region" {
  description = "AWS region for the bootstrap resources"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the Terraform state bucket"
  type        = string
}

variable "github_role_name" {
  description = "Name of the IAM role assumed by GitHub Actions. Defaults to <project_name>-github-actions; set only to adopt an existing role without replacing it"
  type        = string
  default     = null
}

variable "github_owner" {
  description = "GitHub organisation or user that owns the repository"
  type        = string
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID (part of the customised OIDC subject claim)"
  type        = number
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID (part of the customised OIDC subject claim)"
  type        = number
}

variable "github_branch" {
  description = "Branch allowed to assume the role"
  type        = string
}

variable "project_name" {
  description = "Project name; the CI role is scoped to resources named or tagged with it"
  type        = string
}

variable "environment" {
  description = "Environment label applied as a tag to every resource"
  type        = string
}
