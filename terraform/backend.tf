terraform {
  backend "s3" {
    bucket = "ei-terraform-state-2026"
    key    = "hello-cicd/terraform.tfstate"
    region = "eu-west-2"

    use_lockfile = true
  }
}