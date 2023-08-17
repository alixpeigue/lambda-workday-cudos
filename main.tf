terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
  }
}

locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  region   = "eu-west-1"
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

// - Lambda

module "reciever_lambda" {
  source = "./modules/lambda"

  function_name = "workday-cudos-replication-reciever-lambda"

  requirements     = "reciever_lambda/requirements.txt"
  scripts          = ["reciever_lambda/handler.py"]
  handler          = "handler.lambda_handler"
  runtime          = "python3.10"
  archive_filename = "reciever_sources"

  policy_arns = [
    aws_iam_policy.vpc_lambda_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  ]

  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  environment_variables = {
    password = aws_db_instance.db.password
    user     = aws_db_instance.db.username
    db       = aws_db_instance.db.db_name
    host     = aws_db_instance.db.address
    port     = aws_db_instance.db.port
  }
}

module "emitter_lambda" {
  source = "./modules/lambda"

  function_name = "workday-cudos-replication-emitter-lambda"

  requirements     = "emitter_lambda/requirements.txt"
  scripts          = ["emitter_lambda/handler.py"]
  handler          = "handler.lambda_handler"
  runtime          = "python3.10"
  archive_filename = "emitter_sources"

  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  ]

  environment_variables = {
    sqs = aws_sqs_queue.queue.url
  }
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

/////// VPC

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
  name = "workday-replication-vpc"

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]

}

// SQS

resource "aws_sqs_queue" "queue" {
  name                      = "worday-replication-queue"
  message_retention_seconds = 3600
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = module.reciever_lambda.function_name
}

resource "aws_vpc_endpoint" "sqs_vpc_interface" {
  vpc_id             = module.vpc.vpc_id
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.${local.region}.sqs"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.vpc.default_security_group_id]
}
