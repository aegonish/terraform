variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "aegonish"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name (for SSH access)"
  type        = string
  default     = "aegonish-key"
}

variable "allowed_cidr" {
  description = "CIDR blocks allowed for SSH (22) and Jenkins UI (8080). Example: [\"<YOUR_PUBLIC_IP>/32\"]"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
