variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name to deploy ArgoCD onto"
  type        = string
  default     = "aegonish-eks-cluster"
}

variable "argocd_common_name" {
  description = "Common name for ArgoCD self-signed TLS certificate"
  type        = string
  default     = ""
}

variable "my_ip_cidr" {
  description = "Optional: CIDR for your own IP to access ArgoCD externally"
  type        = string
  default     = ""
}
