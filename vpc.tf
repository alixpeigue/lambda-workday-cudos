resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids = module.vpc.private_subnets
  name       = "workday-replication-db-subnet-group"
}

// Ingress rule for lambda to access db
resource "aws_security_group_rule" "ingress_rule_lambda" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  self              = true
  protocol          = "TCP"
  description       = "Lambda access"
}

// Ingress rule for quicksight to access db
resource "aws_security_group_rule" "ingress_rule_quicksight" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  cidr_blocks       = [local.quicksight_region_cidr]
  protocol          = "TCP"
  description       = "Quicksight access"
}

// Egress rule
resource "aws_security_group_rule" "egress_rule" {
  type              = "egress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  self              = true
  protocol          = "TCP"
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  cidr = var.vpc_cidr
  name = "workday-replication-vpc"

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
}