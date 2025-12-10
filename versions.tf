# Terraform and provider version constraints, AWS provider configuration with default tags.

terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.25"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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