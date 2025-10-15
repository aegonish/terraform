variable "project_name" {}
variable "env" {}
variable "vpc_id" {}
variable "subnets" {
  type = list(string)
}