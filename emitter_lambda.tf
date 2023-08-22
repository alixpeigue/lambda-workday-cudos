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