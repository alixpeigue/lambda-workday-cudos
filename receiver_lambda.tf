// Allow lambda to access VPC resources

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

// Lambda

module "receiver_lambda" {
  source = "./modules/lambda"

  function_name = "workday-cudos-replication-receiver-lambda"

  requirements     = "receiver_lambda/requirements.txt"
  scripts          = ["receiver_lambda/handler.py"]
  handler          = "handler.lambda_handler"
  runtime          = "python3.10"
  archive_filename = "receiver_sources"

  policy_arns = [
    aws_iam_policy.vpc_lambda_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  ]

  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  environment_variables = {
    dbname = aws_db_instance.db.db_name
    host   = aws_db_instance.db.address
    port   = aws_db_instance.db.port
    region = local.region
  }
}