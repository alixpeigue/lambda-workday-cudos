locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  quicksight_region_cidr_mapping = { // Cidr of the region whe re this is deployed, see https://docs.aws.amazon.com/quicksight/latest/user/regions.html
    us-east-2      = "52.15.247.160/27",
    us-east-1      = "52.23.63.224/27",
    us-west-2      = "54.70.204.128/27",
    ap-south-1     = "52.66.193.64/27",
    ap-northeast-2 = "13.124.145.32/27",
    ap-southeast-1 = "13.229.254.0/27",
    ap-southeast-2 = "54.153.249.96/27",
    ap-northeast-1 = "13.113.244.32/27",
    ca-central-1   = "15.223.73.0/27",
    eu-central-1   = "35.158.127.192/27",
    eu-west-1      = "52.210.255.224/27",
    eu-west-2      = "35.177.218.0/27",
    eu-west-3      = "13.38.202.0/27",
    eu-north-1     = "13.53.191.64/27",
    sa-east-1      = "18.230.46.192/27",
    gov-west-1     = "160.1.180.32/27"
  }
  quicksight_region_cidr = local.quicksight_region_cidr_mapping[var.region]
}