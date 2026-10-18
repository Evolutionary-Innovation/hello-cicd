variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type to use"
  type        = string
}

variable "project_name" {
  description = "Base name for all resources (IAM role and profile, security group, EIP, ECR repository, container) and the value of the project tag"
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
}

variable "environment" {
  description = "Environment label applied as a tag to every resource"
  type        = string
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to delete the ECR repository even if it still contains images"
  type        = bool
}
