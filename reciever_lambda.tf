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

data "aws_iam_policy_document" "access_secret_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.db.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_policy" "access_secret_policy" {
  name   = "workday-reciever-lambda-access-secret-policy"
  policy = data.aws_iam_policy_document.access_secret_policy_document.json
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
    aws_iam_policy.access_secret_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  ]

  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  environment_variables = {
    secret = aws_db_instance.db.master_user_secret[0].secret_arn
    user   = aws_db_instance.db.username
    db     = aws_db_instance.db.db_name
    host   = aws_db_instance.db.address
    port   = aws_db_instance.db.port
    region = local.region
  }
}