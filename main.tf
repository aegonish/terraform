#########################################
# Provider
#########################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

#########################################
# Modules
#########################################

# --- VPC module ---
module "vpc" {
  source          = "./modules/vpc"
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  cluster_name    = var.cluster_name
  tags            = var.tags

  # Optional — safe even if not provided
  azs = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

# --- IAM module ---
module "iam" {
  source         = "./modules/iam"
  cluster_name   = var.cluster_name
  node_role_name = "${var.cluster_name}-node-role"
  tags           = var.tags
}

# --- ECR module ---
module "ecr" {
  source = "./modules/ecr"
  name   = "${var.cluster_name}-repo"
  tags   = var.tags
}

# --- EKS module ---
module "eks" {
  source                     = "./modules/eks"

  cluster_name               = var.cluster_name
  cluster_version            = var.cluster_version

  # Networking
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  cluster_security_group_id  = module.vpc.cluster_security_group_id

  # IAM
  cluster_role_arn           = module.iam.cluster_role_arn
  cluster_role_name          = module.iam.cluster_role_name   # <--- Added this line
  node_role_arn              = module.iam.node_role_arn

  # Node settings
  node_instance_type         = var.node_instance_type
  desired_size               = var.node_desired_capacity
  min_size                   = var.node_min_size
  max_size                   = var.node_max_size

  tags                       = var.tags
}

