terraform {
  backend "s3" {
    bucket         = "${var.project_name}-tf-state"
    key            = "terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "${var.project_name}-tf-locks"
    encrypt        = true
  }
}