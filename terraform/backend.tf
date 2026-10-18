# Backend blocks cannot use variables: bucket and region must match
# bootstrap/terraform.tfvars (state_bucket_name, aws_region) and terraform.tfvars.
terraform {
  backend "s3" {
    bucket = "ei-terraform-state-2026"
    key    = "hello-cicd/terraform.tfstate"
    region = "eu-west-2"

    use_lockfile = true
  }
}