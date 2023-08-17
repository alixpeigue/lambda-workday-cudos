variable "requirements" {
    description = "pip requirements file"
    default = null
    type = string
}

variable "scripts" {
    description = "python script file"
    type = list(string)
}

variable "role" {
    description = "lambda role"
    type = string
}

variable "function_name" {
    description = "function name"
    type = string
}

variable "handler" {
    description = "function handler"
    type = string
}

variable "runtime" {
    description = "runtime"
    type = string
}

variable "environment_variables" {
    description = "environment variables"
    type = map(string, string)
}

variable "vpc_subnet_ids" {
    description = "list of subnet ids"
    type = list(string)
}

variable "vpc_security_group_ids" {
    description = "list of security group ids"
    type = list(string)
}

variable  "archive_filename" {
    description = "archive_filename"
    type = string
}