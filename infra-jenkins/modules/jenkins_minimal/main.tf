#########################################
# Security Group
#########################################

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow Jenkins UI, SSH, and internal Jenkins communication"
  vpc_id      = var.vpc_id

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr
  }

  # Allow internal traffic between master and slave
  ingress {
    description = "Internal Jenkins communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

#########################################
# Jenkins Master (Free-tier)
#########################################

resource "aws_instance" "jenkins_master" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  tags = {
    Name = "jenkins-master"
    Role = "master"
  }
}

#########################################
# Jenkins Slave (Free-tier)
#########################################

resource "aws_instance" "jenkins_slave" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  tags = {
    Name = "jenkins-slave"
    Role = "slave"
  }

  depends_on = [aws_instance.jenkins_master]
}

#########################################
# Outputs
#########################################



output "jenkins_slave_public_ip" {
  description = "Public IP of Jenkins slave"
  value       = aws_instance.jenkins_slave.public_ip
}



output "jenkins_slave_id" {
  description = "Instance ID of Jenkins slave"
  value       = aws_instance.jenkins_slave.id
}
