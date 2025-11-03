resource "aws_ecr_repository" "this" {
  name                 = var.name
  force_delete         = true  # fix: auto-delete images when deleting repo
  image_tag_mutability = "MUTABLE"
  tags = var.tags
}

