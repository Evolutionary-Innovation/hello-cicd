variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-2"
}

variable "instance_type" {
  description = "The EC2 instance type to use"
  type        = string
  default     = "t3.micro"
}
