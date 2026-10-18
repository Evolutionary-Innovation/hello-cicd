# Bootstrap stack

Owns what the main stack depends on: the Terraform state bucket, the GitHub OIDC
provider, and the GitHub Actions role with its scoped policy. Applied manually with
admin credentials; CI never runs it.

Procedure, gotchas and how to change CI permissions: [docs/bootstrap.md](../docs/bootstrap.md).
