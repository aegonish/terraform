variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
  default = ""
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}


variable "cluster_security_group_id" {
  type = string
  default = ""
}

variable "node_role_arn" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "desired_size" {
  type = number
  default = 2
}

variable "min_size" {
  type = number
  default = 1
}

variable "max_size" {
  type = number
  default = 3
}

variable "tags" {
  type = map(string)
  default = {}
}

# Name of the IAM role used by the EKS cluster
variable "cluster_role_name" {
  description = "Name of the IAM role for the EKS cluster"
  type        = string
}

# ARN of the IAM role used by the EKS cluster (already used in main.tf)
variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster"
  type        = string
}
