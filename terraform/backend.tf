# Bucket, key and region live in backend.hcl (backend blocks cannot use variables):
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    use_lockfile = true
  }
}
