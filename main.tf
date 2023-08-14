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

data "aws_availability_zones" "available" {}

locals {
  vpc_cidr = "10.0.0.0/16"
  name     = "workday-replication"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
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

resource "aws_iam_role_policy_attachment" "attach_vpc_policy_to_role" {
  role       = aws_iam_role.projectinfo_lambda_iam.name
  policy_arn = aws_iam_policy.vpc_lambda_policy.arn
}

data "aws_iam_policy_document" "cloudwatch_logs_lambda_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_logs_lambda_policy" {
  name   = "limited-cloudwatch-logs-policy-for-workday-cudos-update-lambda"
  policy = data.aws_iam_policy_document.cloudwatch_logs_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_to_role" {
  role       = aws_iam_role.projectinfo_lambda_iam.name
  policy_arn = aws_iam_policy.cloudwatch_logs_lambda_policy.arn
}

// - Lambda
resource "aws_lambda_function" "project_infos" {
  function_name = local.name
  filename      = data.archive_file.projectinfos_zip_file.output_path
  role          = aws_iam_role.projectinfo_lambda_iam.arn
  handler       = "workday_cudos_update.lambda_handler"
  runtime       = "python3.10"
  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.vpc.default_security_group_id]
  }
  environment {
    variables = {
      password = aws_db_instance.db.password
      user     = aws_db_instance.db.username
      db       = aws_db_instance.db.db_name
      host     = aws_db_instance.db.address
      port     = aws_db_instance.db.port
    }
  }

  depends_on = [data.archive_file.projectinfos_zip_file]
}

/// EvenBridge Event

resource "aws_cloudwatch_event_rule" "workday_replication_lambda_event_rule" {
  name                = "daily-trigger-for-workday-replication"
  schedule_expression = "rate(24 hours)"
}

resource "aws_cloudwatch_event_target" "workday_replication_lambda_target" {
  arn  = aws_lambda_function.project_infos.arn
  rule = aws_cloudwatch_event_rule.workday_replication_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.project_infos.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.workday_replication_lambda_event_rule.arn
}

/////// RDS

resource "aws_db_instance" "db" {
  identifier     = "workday-replication-db"
  engine         = "postgres"
  engine_version = "14"
  instance_class = "db.t3.micro"

  allocated_storage = "5"

  db_name  = "workdayReplicationDB"
  username = "postgres"
  password = "postgres"
  port     = 5432

  multi_az = false

  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [module.vpc.default_security_group_id]
}

resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids = module.vpc.private_subnets
  name       = "workday-replication-db-subnet-group"
}

resource "aws_security_group_rule" "ingress_rule" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  self              = true
  protocol          = "TCP"
}

resource "aws_security_group_rule" "egress_rule" {
  type              = "egress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  self              = true
  protocol          = "TCP"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  cidr = local.vpc_cidr
  name = local.name

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]

}

// Allow lambda to access internet

resource "aws_internet_gateway" "gateway" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "workday-replication-vpc-internet-gateway"
  }
}
