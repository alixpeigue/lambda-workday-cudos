resource "aws_db_instance" "db" {
  identifier     = "workday-replication-db"
  engine         = "postgres"
  engine_version = "12"
  instance_class = "db.t3.micro"

  allocated_storage = "5"

  db_name  = "workdayReplicationDB"
  username = "postgres"
  port     = 5432
  //password = "postgres"

  manage_master_user_password = true

  multi_az = false

  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [module.vpc.default_security_group_id]
}