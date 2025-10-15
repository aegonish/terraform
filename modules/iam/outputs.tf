# modules/iam/outputs.tf

# EKS Cluster IAM Role Name
output "cluster_role_name" {
  value = aws_iam_role.eks_cluster.name
}

# EKS Cluster IAM Role ARN
output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

# Node Group IAM Role ARN
output "node_role_arn" {
  value = aws_iam_role.node_group.arn
}
