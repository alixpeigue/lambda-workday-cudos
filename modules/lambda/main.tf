terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
    local = {
      source = "hashicorp/local"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

resource "local_file" "this" {
  for_each = toset(var.scripts)

  content_base64 = filebase64(each.value)
  filename       = "${var.archive_filename}/${basename(each.value)}"
  depends_on     = [null_resource.makepkg]
}

resource "null_resource" "makepkg" {
  triggers = {
    requirements = var.requirements != null ? filesha1(var.requirements) : null
    sources      = join("", [for script in var.scripts : filesha1(script)])
  }
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${var.archive_filename}
      mkdir ${var.archive_filename}
      pip install --upgrade --target ./${var.archive_filename} -r ${var.requirements}
    EOT
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.archive_filename
  output_path = "${var.archive_filename}.zip"
  depends_on  = [local_file.this, null_resource.makepkg]
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  filename      = data.archive_file.this.output_path
  role          = var.role != null ? var.role : aws_iam_role.this[0].arn
  handler       = var.handler
  runtime       = var.runtime
  vpc_config {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  }
  environment {
    variables = var.environment_variables
  }
  tags = var.tags
}

// Role

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

resource "aws_iam_role" "this" {
  count              = var.role == null ? 1 : 0
  name               = var.role_name != null ? var.role_name : "${var.function_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.changerole_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {for i, val in var.policy_arns: i => val}

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}