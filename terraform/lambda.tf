# ─── ECR Repository ───
resource "aws_ecr_repository" "compliance_checker" {
  name                 = "${var.project}-compliance-checker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project
  }
}

resource "aws_ecr_repository" "auto_remediation" {
  name                 = "${var.project}-auto-remediation"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project
  }
}

# ─── CloudWatch Log Groups ───
resource "aws_cloudwatch_log_group" "compliance_checker" {
  name              = "/aws/lambda/${var.project}-compliance-checker"
  retention_in_days = 7

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_log_group" "auto_remediation" {
  name              = "/aws/lambda/${var.project}-auto-remediation"
  retention_in_days = 7

  tags = {
    Project = var.project
  }
}

# ─── Compliance Checker Lambda Function ───
resource "aws_lambda_function" "compliance_checker" {
  function_name = "${var.project}-compliance-checker"
  role          = aws_iam_role.compliance_checker.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.compliance_checker.repository_url}:latest"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      TABLE_NAME       = aws_dynamodb_table.violations.id
      SNS_TOPIC_ARN    = aws_sns_topic.alerts.arn
      DASHBOARD_BUCKET = aws_s3_bucket.dashboard.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.compliance_checker]

  tags = {
    Project = var.project
  }
}

# ─── Auto Remediation Lambda Function ───
resource "aws_lambda_function" "auto_remediation" {
  function_name = "${var.project}-auto-remediation"
  role          = aws_iam_role.auto_remediation.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.auto_remediation.repository_url}:latest"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      TABLE_NAME       = aws_dynamodb_table.violations.id
      SNS_TOPIC_ARN    = aws_sns_topic.alerts.arn
      DASHBOARD_BUCKET = aws_s3_bucket.dashboard.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.auto_remediation]

  tags = {
    Project = var.project
  }
}

# ─── API Gateway Handler Lambda ───
resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project}-api-handler"
  role          = aws_iam_role.compliance_checker.arn
  package_type  = "Image"
  image_uri = "${aws_ecr_repository.api_handler.repository_url}:latest"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      TABLE_NAME       = aws_dynamodb_table.violations.id
      SNS_TOPIC_ARN    = aws_sns_topic.alerts.arn
      DASHBOARD_BUCKET = aws_s3_bucket.dashboard.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.compliance_checker]

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_log_group" "api_handler" {
  name              = "/aws/lambda/${var.project}-api-handler"
  retention_in_days = 7

  tags = {
    Project = var.project
  }
}

resource "aws_ecr_repository" "api_handler" {
  name                 = "${var.project}-api-handler"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project
  }
}