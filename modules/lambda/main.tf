terraform {
  required_providers {
    aws = {
      version = "~> 5.11.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "archive" {}

resource "local_file" "this"{
  for_each = toset(var.scripts)

  content_base64 = filebase64(each.value)
  filename       = "tmp/${each.value}"
  depends_on = [null_resource.makepkg]
}

resource "null_resource" "makepkg" {
  triggers = {
    requirements = var.requirements != null ? filesha1(var.requirements) : null
    sources = [for script in var.scrpits : filesha1(script)]
  }
  provisioner "local-exec" {
    command = <<EOT
      rm -rf tmp
      mkdir tmp
      pip install --upgrade --target ./tmp -r ${var.requirements}
    EOT
  }
}

data "archive_file" "this" {
  type = "zip"
  source_dir = "tmp"
  output_path = var.archive_filemane
  depends_on = [local_file.this, null_resource.makepkg]
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  filename = data.archive_file.this.output_path
  role = var.role
  handler = var.handler
  runtime = var.runtime
  vpc_config {
    subnet_ids = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  }
  environment {
    variables = var.environment_variables
  }
}