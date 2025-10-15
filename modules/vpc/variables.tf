variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "cluster_name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "azs" {
  description = "Availability zones to use (at least 2 recommended). Defaults to region AZs."
  type = list(string)
  default = []
}
