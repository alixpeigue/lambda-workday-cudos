// Allow lambda to access Secrets Manager secret for db credentials

data "aws_iam_policy_document" "access_secret_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.db.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_policy" "access_secret_policy" {
  name   = "workday-emitter-lambda-access-secret-policy"
  policy = data.aws_iam_policy_document.access_secret_policy_document.json
}

// Allow to access SQS

data "aws_iam_policy_document" "sqs_emitter_lambda_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:*"
    ]
    resources = [
      aws_sqs_queue.queue.arn
    ]
  }
}

resource "aws_iam_policy" "sqs_emitter_lambda_policy" {
  name   = "sqs-iam-policy-for-workday-cudos-emitter-lambda"
  policy = data.aws_iam_policy_document.sqs_emitter_lambda_policy_document.json
}

// Lambda

module "emitter_lambda" {
  source = "./modules/lambda"

  function_name = "workday-cudos-replication-emitter-lambda"

  requirements     = "emitter_lambda/requirements.txt"
  scripts          = ["emitter_lambda/handler.py"]
  handler          = "handler.lambda_handler"
  runtime          = "python3.10"
  archive_filename = "emitter_sources"

  policy_arns = [
    aws_iam_policy.access_secret_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.sqs_emitter_lambda_policy.arn
  ]

  environment_variables = {
    sqs    = aws_sqs_queue.queue.url
    secret = aws_db_instance.db.master_user_secret[0].secret_arn
    region = var.region
  }
}

/// EvenBridge, trigger lambde every 24 hours

resource "aws_cloudwatch_event_rule" "workday_replication_lambda_event_rule" {
  name                = "daily-trigger-for-workday-replication"
  schedule_expression = "rate(24 hours)"
}

resource "aws_cloudwatch_event_target" "workday_replication_lambda_target" {
  arn  = module.emitter_lambda.function_arn
  rule = aws_cloudwatch_event_rule.workday_replication_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.emitter_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.workday_replication_lambda_event_rule.arn
}