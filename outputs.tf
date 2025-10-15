output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "backend_ecr_uri" {
  value = module.ecr.backend_repo_uri
}

output "frontend_ecr_uri" {
  value = module.ecr.frontend_repo_uri
}

output "jenkins_role_arn" {
  value = module.iam.jenkins_role_arn
}