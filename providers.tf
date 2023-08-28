terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Production = "False"
      IaC        = "Terraform"
    }
  }
}