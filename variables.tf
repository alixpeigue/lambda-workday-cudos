variable "vpc_cidr" {
  description = "le CIDR du VPC dans lequel seront placées la base de données et la fonction réceptrice"
  type        = string
}

variable "region" {
  description = "région de déploiement"
  type        = string
}

variable "quicksight_secretsmanager_role" {
  description = "le rôle avec lequel est configuré quicksight pour accéder aux informations de connexion de la base de données"
  type        = string
  default     = "aws-quicksight-secretsmanager-role-v0"
}

variable "quicksight_group" {
  description = "l'ARN du groupe quicksight qui sera autorisé à accéder à la Data Source et au Data Set créés"
  type        = string
}