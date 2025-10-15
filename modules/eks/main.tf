module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.25.0"

  cluster_name    = var.project_name
  cluster_version = "1.27"
  vpc_id          = var.vpc_id
  subnets         = var.subnets

  node_groups = {
    dev_nodes = {
      desired_capacity = 1
      max_capacity     = 1
      min_capacity     = 1
      instance_type    = "t3.micro"
    }
  }

  tags = {
    Env = var.env
  }
}