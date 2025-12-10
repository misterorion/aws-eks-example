terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.25"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "sandbox"
      Project     = "aws-eks-example"
      ManagedBy   = "Terraform"
    }
  }
}