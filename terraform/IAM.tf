data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ─── Compliance Checker Lambda Role ───
resource "aws_iam_role" "compliance_checker" {
  name               = "${var.project}-compliance-checker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "compliance_checker" {
  name = "${var.project}-compliance-checker-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.violations.arn,
          "${aws_dynamodb_table.violations.arn}/index/*"
        ]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-micro-v1:0"
      },
      {
        Sid    = "ConfigRead"
        Effect = "Allow"
        Action = [
          "config:GetComplianceDetailsByConfigRule",
          "config:DescribeConfigRules"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "compliance_checker" {
  role       = aws_iam_role.compliance_checker.name
  policy_arn = aws_iam_policy.compliance_checker.arn
}

# ─── Auto Remediation Lambda Role ───
resource "aws_iam_role" "auto_remediation" {
  name               = "${var.project}-auto-remediation-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "auto_remediation" {
  name = "${var.project}-auto-remediation-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "DynamoDBUpdate"
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.violations.arn,
          "${aws_dynamodb_table.violations.arn}/index/*"
        ]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "S3Remediation"
        Effect = "Allow"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailRemediation"
        Effect = "Allow"
        Action = [
          "cloudtrail:StartLogging",
          "cloudtrail:GetTrailStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaLoggingRemediation"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "auto_remediation" {
  role       = aws_iam_role.auto_remediation.name
  policy_arn = aws_iam_policy.auto_remediation.arn
}

# ─── OIDC Provider for GitHub Actions ───
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:Prat-1234/aws-compliance-drift-detector:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformDeploy"
        Effect = "Allow"
        Action = [
          "lambda:*",
          "iam:PassRole",
          "ecr:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}