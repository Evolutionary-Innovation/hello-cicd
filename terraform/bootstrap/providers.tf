terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      managed-by  = "terraform"
      project     = "tf-learning"
      environment = "dev"
    }
  }
}
