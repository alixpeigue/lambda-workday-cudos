resource "aws_iam_role" "vpc_connection_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "quicksight.amazonaws.com"
        }
      }
    ]
  })
  inline_policy {
    name = "QuickSightVPCConnectionRolePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:ModifyNetworkInterfaceAttribute",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups"
          ]
          Resource = ["*"]
        }
      ]
    })
  }
}

resource "aws_iam_policy" "access_secretsmanager_policy" {
  name = "QuicksightReadOnlyAccessForSecretMAnagerRDSWorkdayReplication"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_db_instance.db.master_user_secret[0].secret_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "access_secretsmanager" {
  role       = local.quicksight_secretsmanager_role
  policy_arn = aws_iam_policy.access_secretsmanager_policy.arn
}

resource "aws_quicksight_vpc_connection" "vpc_connection" {
  vpc_connection_id  = "workday-rds-connection"
  name               = "Workday RDS Connection"
  role_arn           = aws_iam_role.vpc_connection_role.arn
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
}

resource "aws_secretsmanager_secret_policy" "secret_quicksight_policy" {
  secret_arn = aws_db_instance.db.master_user_secret[0].secret_arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/${local.quicksight_secretsmanager_role}"
        },
        Action   = "secretsmanager:GetSecretValue",
        Resource = ["*"]
      }
    ]
  })
}

# We use cloudformation because terraform cannot use a secret as credentials for a QuickSight Data Source
resource "aws_cloudformation_stack" "quicksight_datasource" {
  name = "workday-rds-quicksight-datasource"
  parameters = {
    VpcConnection = aws_quicksight_vpc_connection.vpc_connection.arn
    Secret        = aws_db_instance.db.master_user_secret[0].secret_arn
    Database      = aws_db_instance.db.db_name
    Instance      = aws_db_instance.db.identifier
    Account       = data.aws_caller_identity.current.account_id
  }
  template_body = <<EOT
    AWSTemplateFormatVersion: 2010-09-09
    Parameters:
      VpcConnection:
        Type: String
      Secret:
        Type: String
      Database:
        Type: String
      Instance:
        Type: String
      Account:
        Type: String
    Resources:
      WorkdayDataSource:
        Type: 'AWS::QuickSight::DataSource'
        Properties:
          AwsAccountId: !Ref Account
          VpcConnectionProperties:
            VpcConnectionArn: !Ref VpcConnection
          Type: POSTGRESQL
          Credentials:
            SecretArn: !Ref Secret
          Name: Workday RDS Source
          DataSourceId: 'workday-rds-source'
          DataSourceParameters:
            RdsParameters:
              Database: !Ref Database
              InstanceId: !Ref Instance 
  EOT
}