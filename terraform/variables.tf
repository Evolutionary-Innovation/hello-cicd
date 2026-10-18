variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type to use"
  type        = string
}

variable "project_name" {
  description = "Base name for all resources (role, profile, security group, EIP, key pair, ECR repository, container)"
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
}
