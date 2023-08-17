variable "requirements" {
  description = "pip requirements file"
  default     = null
  type        = string
}

variable "scripts" {
  description = "python script file"
  type        = list(string)
}

variable "role" {
  description = "lambda role"
  type        = string
  default     = null
}

variable "function_name" {
  description = "function name"
  type        = string
}

variable "handler" {
  description = "function handler"
  type        = string
}

variable "runtime" {
  description = "runtime"
  type        = string
}

variable "environment_variables" {
  description = "environment variables"
  type        = map(any)
}

variable "vpc_subnet_ids" {
  description = "list of subnet ids"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "list of security group ids"
  type        = list(string)
  default     = []
}

variable "archive_filename" {
  description = "source archive filename"
  type        = string
}

variable "role_name" {
  description = "created execution role name"
  type        = string
  default     = null
}

variable "policy_arns" {
  description = "list of arn of policies to attach to created execution role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "tags for lambda function"
  type        = map(string)
  default     = {}
}