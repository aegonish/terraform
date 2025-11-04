#########################################
# Terraform & Providers
#########################################
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "aegonish-tf-state"
    key    = "infra-argocd/terraform.tfstate"
    region = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#########################################
# Data Sources
#########################################

# Get public IP of Jenkins runner (for SG restriction)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr = var.my_ip_cidr != "" ? var.my_ip_cidr : "${trimspace(data.http.my_ip.body)}/32"
}

# Get existing EKS cluster info
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

#########################################
# Kubernetes & Helm Providers
#########################################
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

#########################################
# ArgoCD Namespace
#########################################
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

#########################################
# Security Group for ArgoCD LoadBalancer
#########################################
resource "aws_security_group" "argocd_alb_sg" {
  name        = "${var.cluster_name}-argocd-sg"
  description = "Security group for ArgoCD ALB"
  vpc_id      = var.vpc_id
  tags        = var.tags

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
    description = "Allow HTTPS from developer IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#########################################
# TLS (Self-Signed)
#########################################
resource "tls_private_key" "argocd" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "argocd" {
  subject {
    common_name  = var.argocd_common_name != "" ? var.argocd_common_name : data.aws_eks_cluster.eks.endpoint
    organization = ["aegonish"]
  }

  validity_period_hours = 8760
  is_ca_certificate     = false
  private_key_pem       = tls_private_key.argocd.private_key_pem
}

resource "kubernetes_secret" "argocd_tls" {
  metadata {
    name      = "argocd-server-tls"
    namespace = var.namespace
  }

  data = {
    "tls.crt" = base64encode(tls_self_signed_cert.argocd.cert_pem)
    "tls.key" = base64encode(tls_private_key.argocd.private_key_pem)
  }

  type = "kubernetes.io/tls"
  depends_on = [kubernetes_namespace.argocd]
}

#########################################
# ArgoCD Admin Credentials
#########################################
resource "random_password" "admin" {
  length  = 20
  special = true
}

resource "aws_secretsmanager_secret" "argocd_admin" {
  name        = "${var.cluster_name}-argocd-admin"
  description = "ArgoCD admin credentials"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "argocd_admin_ver" {
  secret_id     = aws_secretsmanager_secret.argocd_admin.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.admin.result
  })
}

#########################################
# Helm Install: ArgoCD
#########################################
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argo_chart_version

  values = [
    <<EOF
server:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-security-groups: "${aws_security_group.argocd_alb_sg.id}"
  extraArgs:
    - --insecure
    - --staticassets
dex:
  enabled: true
redis:
  enabled: true
EOF
  ]

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = random_password.admin.result
  }

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_tls
  ]
}

#########################################
# Outputs
#########################################
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}

output "argocd_endpoint" {
  value = try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "argocd_admin_secret_arn" {
  value = aws_secretsmanager_secret.argocd_admin.arn
}
