resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids = module.vpc.private_subnets
  name       = "workday-replication-db-subnet-group"
}

resource "aws_security_group_rule" "ingress_rule_lambda" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  self              = true
  protocol          = "TCP"
  description       = "Lambda access"
}

resource "aws_security_group_rule" "ingress_rule_quicksight" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  security_group_id = module.vpc.default_security_group_id
  cidr_blocks       = ["13.38.202.0/27"] // TODO: change to paramerer
  protocol          = "TCP"
  description       = "Quicksight access"
}

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

  cidr = local.vpc_cidr
  name = "workday-replication-vpc"

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]

}