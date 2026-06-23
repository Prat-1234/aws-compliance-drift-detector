resource "aws_dynamodb_table" "violations" {
  name         = "${var.project}-violations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "violation_id"
  range_key    = "timestamp"

  attribute {
    name = "violation_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  tags = {
    Project = var.project
  }
}