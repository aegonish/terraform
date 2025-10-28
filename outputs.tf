output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "kubeconfig" {
  description = "Suggested kubeconfig (local exec to write is not included). Use these outputs to build kubeconfig."
  value = {
    endpoint = module.eks.cluster_endpoint
    certificate_authority_data = module.eks.cluster_certificate_authority_data
    name = module.eks.cluster_name
  }
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}


