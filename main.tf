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
  cluster_role_name          = module.iam.cluster_role_name
  node_role_arn              = module.iam.node_role_arn

  # Node settings
  node_instance_type         = var.node_instance_type
  desired_size               = var.node_desired_capacity
  min_size                   = var.node_min_size
  max_size                   = var.node_max_size

  tags                       = var.tags

  depends_on = [module.iam, module.vpc]
}

#########################################
# Secrets Manager (dynamic name)
#########################################

locals {
  timestamp_suffix     = formatdate("YYYYMMDDHHmmss", timestamp())
  dynamic_secret_name  = "${var.cluster_name}-app-secrets-${local.timestamp_suffix}"
}

resource "aws_secretsmanager_secret" "app_secrets" {
  name        = local.dynamic_secret_name
  description = "Application secrets for ${var.cluster_name}, generated at ${local.timestamp_suffix}"
  tags        = var.tags

  recovery_window_in_days = 0
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets_version" {
  secret_id     = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode(var.app_secrets)
}

output "app_secrets_name" {
  description = "The dynamic name of the stored app secrets"
  value       = aws_secretsmanager_secret.app_secrets.name
}

#############################################
# EBS CSI Add-on (AWS-managed, IRSA-ready)
#############################################

# 1. Get cluster data (depends on module.eks)
data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# 2. Create OIDC provider (for IRSA)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  # Amazon root CA thumbprint (valid as of 2025 - keep updated in long term)
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10eb2"]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

#############################################
# IRSA Role for EBS CSI Driver
#############################################

# Use data by name (safer than hard-coding ARN strings)
data "aws_iam_policy" "ebs_csi_policy" {
  name = "AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_irsa" {
  name               = "${var.cluster_name}-ebs-csi-irsa"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  role       = aws_iam_role.ebs_csi_irsa.name
  policy_arn = data.aws_iam_policy.ebs_csi_policy.arn
}

# Single EKS Addon resource, linked to the IRSA role
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                 = module.eks.cluster_name
  addon_name                   = "aws-ebs-csi-driver"
  service_account_role_arn     = aws_iam_role.ebs_csi_irsa.arn
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  timeouts {
    create = "40m"
    update = "40m"
  }

  depends_on = [
    module.eks,
    aws_iam_openid_connect_provider.eks,
    aws_iam_role.ebs_csi_irsa
  ]
}
