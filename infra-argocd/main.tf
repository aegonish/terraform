#########################################
# Terraform Backend & Providers
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
# EKS Cluster Data
#########################################

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

#########################################
# Kubernetes Provider
#########################################

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

#########################################
# Helm Provider (for ArgoCD)
#########################################

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

#########################################
# TLS Certificate (Self-Signed)
#########################################

resource "tls_private_key" "argocd" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "argocd" {
  subject {
    common_name  = var.argocd_common_name != "" ? var.argocd_common_name : data.aws_eks_cluster.eks.endpoint
    organization = "aegonish"
  }

  validity_period_hours = 8760
  is_ca_certificate     = false
  private_key_pem       = tls_private_key.argocd.private_key_pem

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

#########################################
# Detect Public IP for Access (Optional)
#########################################

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_ip_cidr = var.my_ip_cidr != "" ? var.my_ip_cidr : "${trimspace(data.http.my_ip.response_body)}/32"
}

#########################################
# ArgoCD Namespace
#########################################

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

#########################################
# ArgoCD via Helm Chart
#########################################

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.5.2"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.ingress.enabled"
    value = "false"
  }

  set {
    name  = "configs.params.server.insecure"
    value = "true"
  }

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  depends_on = [kubernetes_namespace.argocd]
}

#########################################
# AWS Secrets Manager for Admin Password
#########################################

data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd]
}

resource "aws_secretsmanager_secret" "argocd_admin_secret" {
  name        = "argocd-admin-password"
  description = "ArgoCD admin password stored securely"
}

resource "aws_secretsmanager_secret_version" "argocd_admin_secret_version" {
  secret_id     = aws_secretsmanager_secret.argocd_admin_secret.id
  secret_string = base64decode(data.kubernetes_secret.argocd_admin.data["password"])
}

#########################################
# Get ArgoCD LoadBalancer Service
#########################################

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

#########################################
# Outputs
#########################################

output "argocd_server_url" {
  description = "ArgoCD external endpoint (LoadBalancer)"
  value       = try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "argocd_admin_secret_arn" {
  description = "ARN of the secret storing ArgoCD admin password"
  value       = aws_secretsmanager_secret.argocd_admin_secret.arn
}
