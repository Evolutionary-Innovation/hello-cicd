# Backend blocks cannot use variables: bucket and region must match
# state_bucket_name and aws_region in terraform.tfvars.
terraform {
  backend "s3" {
    bucket = "ei-terraform-state-2026"
    key    = "bootstrap/terraform.tfstate"
    region = "eu-west-2"

    use_lockfile = true
  }
}
