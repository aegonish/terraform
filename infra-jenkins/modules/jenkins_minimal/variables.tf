variable "vpc_id" {
  description = "VPC ID"
}
variable "public_subnet_id" {
  description = "Public subnet ID"
}
variable "key_pair_name" {
  description = "EC2 key pair for SSH"
  type        = string
  default     = "aegonish-key"
}
variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
}
variable "allowed_cidr" {
  description = "CIDR blocks allowed for Jenkins & SSH"
  type        = list(string)
  default     = ["117.204.226.153/32"]
}
