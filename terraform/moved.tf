moved {
  from = aws_ecr_repository.hello_cicd
  to   = aws_ecr_repository.app
}

moved {
  from = aws_ecr_lifecycle_policy.hello_cicd
  to   = aws_ecr_lifecycle_policy.app
}
