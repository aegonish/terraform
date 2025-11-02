terraform {
  required_version = ">= 1.5.0"

    backend "s3" {
    bucket = "aegonish-tf-state"
    key    = "infra-jenkins/terraform.tfstate"
    region = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
 # profile = var.aws_profile
}

#########################################
# Networking (default VPC & subnet)
#########################################

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# ✅ FIX: Use aws_subnets instead of aws_subnets_ids (typo + deprecated)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

#########################################
# AMI (Free-tier Amazon Linux 2)
#########################################

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#########################################
# Jenkins Minimal EC2
#########################################

module "jenkins_minimal" {
  source           = "./modules/jenkins_minimal"
  vpc_id           = data.aws_vpc.default.id
  public_subnet_id = data.aws_subnets.default.ids[0]
  ami_id           = data.aws_ami.amazon_linux_2.id
  key_pair_name    = var.key_pair_name
  allowed_cidr     = var.allowed_cidr
}
