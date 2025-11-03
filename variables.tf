variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile (leave empty to use environment credentials)"
  type        = string
  default     = "aegonish"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "aegonish-eks-cluster"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24","10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24","10.0.102.0/24"]
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_desired_capacity" {
  description = "Desired worker node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum worker node count"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum worker node count"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to resources"
  type = map(string)
  default = {
    Environment = "dev"
    Project     = "aegonish"
    "ManagedBy" = "terraform"
  }
}

variable "app_secrets" {
  description = "Map of application secrets to store in AWS Secrets Manager"
  type        = map(string)
  sensitive   = true
}

