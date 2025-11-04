output "argocd_endpoint" {
  description = "Public ArgoCD endpoint"
  value       = try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "argocd_admin_secret_arn" {
  description = "AWS Secrets Manager ARN with ArgoCD admin credentials"
  value       = aws_secretsmanager_secret.argocd_admin.arn
}
