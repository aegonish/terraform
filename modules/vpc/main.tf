module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.16.0"

  name = var.project_name
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]

  enable_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_name
    Env  = var.env
  }
}