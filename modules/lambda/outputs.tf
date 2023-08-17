output "function_name" {
  value = var.function_name
}

output "execution_role_arn" {
  value = var.role != null ? var.role : aws_iam_role.this[0].arn
}

