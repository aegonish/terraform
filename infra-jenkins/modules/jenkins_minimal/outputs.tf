output "jenkins_master_public_ip" {
  description = "Public IP of the Jenkins master instance"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_master_id" {
  description = "Instance ID of the Jenkins master"
  value       = aws_instance.jenkins_master.id
}
