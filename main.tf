provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region
}

module "eks" {
  source       = "./modules/eks"
  project_name = var.project_name
  env          = var.env
  vpc_id       = module.vpc.vpc_id
  subnets      = module.vpc.public_subnets
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  env          = var.env
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  env          = var.env
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tf-state"
  acl    = "private"

  tags = {
    Name = "${var.project_name}-tf-state"
    Env  = var.env
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.project_name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-tf-locks"
    Env  = var.env
  }
}