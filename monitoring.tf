# Monitoring & Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.shortener.function_name
  }
  statistic            = "Sum"
  period               = 300
  evaluation_periods   = 1
  threshold            = 1
  comparison_operator   = "GreaterThanThreshold"
  alarm_description    = "Alert on Lambda errors"
  treat_missing_data   = "notBreaching"
}