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
# Detect Public IP (Optional)
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
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
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
# AWS Secrets Manager for ArgoCD Admin Password
#########################################

locals {
  timestamp_suffix      = formatdate("YYYYMMDDHHmmss", timestamp())
  dynamic_argocd_secret = "argocd-admin-password-${local.timestamp_suffix}"
}

data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd]
}

resource "aws_secretsmanager_secret" "argocd_admin_secret" {
  name        = local.dynamic_argocd_secret
  description = "Dynamic ArgoCD admin password secret created at ${local.timestamp_suffix}"

  recovery_window_in_days = 0

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "argocd_admin_secret_version" {
  secret_id     = aws_secretsmanager_secret.argocd_admin_secret.id
  secret_string = data.kubernetes_secret.argocd_admin.data["password"]
}

#########################################
# Get ArgoCD LoadBalancer Endpoint
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

#########################################
# ArgoCD Git Repository Credentials
#########################################

variable "git_repo_url" {
  type        = string
  default     = "https://github.com/aegonish/terraform"
  description = "Git repo ArgoCD will sync from"
}

variable "git_repo_username" {
  type        = string
  default     = ""
  description = "Git username (optional if using token auth)"
}

variable "git_repo_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GitHub personal access token for ArgoCD"
}

resource "kubernetes_secret" "argocd_repo_creds" {
  metadata {
    name      = "argocd-repo-creds"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url      = base64encode(var.git_repo_url)
    username = base64encode(var.git_repo_username)
    password = base64encode(var.git_repo_token)
  }

  type       = "Opaque"
  depends_on = [helm_release.argocd]
}

#########################################
# ArgoCD Bootstrap (GitOps)
#########################################

resource "null_resource" "apply_argocd_bootstrap" {
  triggers = {
    cluster = var.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<EOT
Write-Host "Waiting for argocd-server to become available..."
kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=300s
Write-Host "Applying ArgoCD bootstrap Application..."
kubectl apply -f gitops/argocd/argocd-bootstrap-application.yaml
EOT
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_repo_creds
  ]
}

output "argocd_summary" {
  value = {
    argocd_url  = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname
    secret_name = aws_secretsmanager_secret.argocd_admin_secret.name
  }
}

#########################################
# AWS Load Balancer Controller (Dynamic IRSA)
#########################################

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# Get current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Reference the existing OIDC provider for the EKS cluster dynamically
data "aws_iam_openid_connect_provider" "eks" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"

  policy = file("${path.module}/iam_policies/aws-load-balancer-controller-policy.json")
}


data "aws_iam_policy_document" "alb_irsa_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.alb_irsa_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "kubernetes_service_account" "alb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller_sa.metadata[0].name
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller_attach,
    kubernetes_service_account.alb_controller_sa
  ]
}
