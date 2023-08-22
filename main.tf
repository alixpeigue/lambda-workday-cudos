terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
  }
}

locals {
  vpc_cidr                           = "10.0.0.0/16"
  azs                                = slice(data.aws_availability_zones.available.names, 0, 3)
  region                             = "eu-west-3"
  quicksight_secretsmanager_role     = "aws-quicksight-secretsmanager-role-v0"
}

// AWS :
provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Production = "False"
      IaC        = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

