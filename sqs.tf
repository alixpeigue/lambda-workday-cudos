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