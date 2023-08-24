terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
  }
}

locals {
  vpc_cidr                       = "10.0.0.0/16"
  azs                            = slice(data.aws_availability_zones.available.names, 0, 3)
  region                         = "eu-west-3"
  quicksight_secretsmanager_role = "aws-quicksight-secretsmanager-role-v0"
  quicksight_group               = "arn:aws:quicksight:eu-west-3:135225040694:group/default/Stagiaires"
  quicksight_region_cidr         = "13.38.202.0/27" // Cidr of the region whe re this is deployed, see https://docs.aws.amazon.com/quicksight/latest/user/regions.html
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

