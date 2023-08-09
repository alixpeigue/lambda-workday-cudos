terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
  }
}

// Archive
provider "archive" {}

// AWS :
provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      Production = "False"
      IaC        = "Terraform"
    }
  }
}

data "archive_file" "projectinfos_zip_file" {
  type        = "zip"
  source_dir  = "package"
  output_path = "workday_cudos_update.zip"
  depends_on  = [null_resource.lambda_makepkg]
}

locals {
  name = "workday-replication"
}

resource "null_resource" "lambda_makepkg" {
  triggers = {
    requirements = filesha1("requirements.txt")
    source       = filesha1("workday_cudos_update.py")
  }
  provisioner "local-exec" {
    command = <<EOT
      pip install --upgrade --target ./package -r requirements.txt
      cp workday_cudos_update.py package/workday_cudos_update.py
    EOT
  }
}

// - Policy
data "aws_iam_policy_document" "changerole_lambda_policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "projectinfo_lambda_iam" {
  name = "limited-projectinfo_lambda_iam"
  //permissions_boundary = "arn:aws:iam::135225040694:policy/SysopsPermissionsBoundary"
  assume_role_policy = data.aws_iam_policy_document.changerole_lambda_policy.json

}

data "aws_iam_policy_document" "vpc_lambda_policy_document" {
  statement {
    effect = "Allow"
    # principals {
    #   identifiers = ["lambda.amazonaws.com"]
    #   type        = "Service"
    # }
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "vpc_lambda_policy" {
  name   = "limited-vpc-iam-policy-for-workday-cudos-update-lambda"
  policy = data.aws_iam_policy_document.vpc_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  role       = aws_iam_role.projectinfo_lambda_iam.name
  policy_arn = aws_iam_policy.vpc_lambda_policy.arn
}

// - Lambda
resource "aws_lambda_function" "project_infos" {
  function_name = local.name
  filename      = data.archive_file.projectinfos_zip_file.output_path
  role          = aws_iam_role.projectinfo_lambda_iam.arn
  handler       = "workday_cudos_update.lambda_handler"
  runtime       = "python3.11"
  vpc_config {
    subnet_ids         = module.vpc.intra_subnets
    security_group_ids = [module.vpc.default_security_group_id]
  }
  environment {
    variables = {
      password = "Test123!"
      user     = module.db.db_instance_username
      db       = module.db.db_instance_name
      host     = module.db.db_instance_address
      port     = module.db.db_instance_port
    }
  }
}

/////// RDS

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "workday-replication-db"

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t3.micro"

  allocated_storage     = 5
  max_allocated_storage = 10

  db_name  = "workdayReplicationDB"
  username = "test_user"
  password = "Test123!"
  port     = 5432

  multi_az             = false
  db_subnet_group_name = module.vpc.database_subnet_group
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name          = local.name
  azs           = ["eu-west-1a"]
  intra_subnets = ["10.0.0.0/24"]

}
