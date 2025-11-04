variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  description = "Existing EKS cluster name"
  type        = string
  default     = "aegonish-eks-cluster"
}

variable "vpc_id" {
  description = "VPC ID where ALB SG will be created"
  type        = string
}

variable "namespace" {
  description = "Namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "my_ip_cidr" {
  description = "CIDR for allowed access (optional override)"
  type        = string
  default     = ""
}

variable "argocd_common_name" {
  description = "Common name for self-signed TLS cert"
  type        = string
  default     = "argocd.local"
}

variable "argo_chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Project     = "aegonish"
    ManagedBy   = "terraform"
  }
}
