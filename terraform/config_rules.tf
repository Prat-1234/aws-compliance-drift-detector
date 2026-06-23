# ─── Config Recorder Setup ───
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.reports.id
  depends_on     = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# ─── IAM Role for Config ───
resource "aws_iam_role" "config_role" {
  name = "${var.project}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy_attachment" "config_role" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "${var.project}-config-s3-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketAcl"
      ]
      Resource = [
        aws_s3_bucket.reports.arn,
        "${aws_s3_bucket.reports.arn}/*"
      ]
    }]
  })
}

# ─── 7 Managed Config Rules ───
resource "aws_config_config_rule" "s3_public_read" {
  name = "${var.project}-s3-no-public-read"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "s3_public_write" {
  name = "${var.project}-s3-no-public-write"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "${var.project}-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "root_mfa" {
  name = "${var.project}-root-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "ssh_restricted" {
  name = "${var.project}-ssh-restricted"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "ebs_encrypted" {
  name = "${var.project}-ebs-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}

resource "aws_config_config_rule" "iam_password_policy" {
  name = "${var.project}-iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Project = var.project
  }
}