resource "aws_ecr_repository" "supportdesk" {
  name                 = "supportdesk"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.allow_force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "supportdesk" {
  repository = aws_ecr_repository.supportdesk.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the three newest SupportDesk images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
