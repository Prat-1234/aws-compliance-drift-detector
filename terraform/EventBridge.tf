resource "aws_cloudwatch_event_rule" "config_compliance" {
  name        = "${var.project}-config-noncompliant"
  description = "Fires when AWS Config detects a NON_COMPLIANT resource"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_event_target" "compliance_checker_lambda" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "ComplianceCheckerLambda"
  arn       = aws_lambda_function.compliance_checker.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_compliance.arn
}