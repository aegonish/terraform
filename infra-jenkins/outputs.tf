output "jenkins_master_public_ip" {
  description = "Public IP of Jenkins master"
  value       = module.jenkins_minimal.jenkins_master_public_ip
}

output "jenkins_master_id" {
  description = "Instance ID of Jenkins master"
  value       = module.jenkins_minimal.jenkins_master_id
}
