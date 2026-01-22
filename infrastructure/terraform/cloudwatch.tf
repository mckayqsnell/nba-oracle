# =============================================================================
# CloudWatch Alerting (Email Only)
# Architecture: CloudWatch Alarm → SNS Topic → Email
# =============================================================================

# =============================================================================
# SNS Topic for Alerts
# =============================================================================

resource "aws_sns_topic" "alerts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  name = "${var.project_name}-alerts-${var.environment}"

  tags = {
    Name = "${var.project_name}-alerts-${var.environment}"
  }
}

# SNS Topic Policy - Allow CloudWatch to publish
resource "aws_sns_topic_policy" "alerts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  arn = aws_sns_topic.alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts[0].arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      }
    ]
  })
}

# Email subscription
resource "aws_sns_topic_subscription" "email" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =============================================================================
# EC2 Alarms
# =============================================================================

# EC2 CPU Utilization Alarm
# Triggers when average CPU > threshold for 2 consecutive 5-minute periods (10 min total)
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-ec2-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = var.ec2_cpu_threshold
  treat_missing_data  = "notBreaching" # Missing data = OK (prevents false alarms)

  dimensions = {
    InstanceId = aws_instance.api.id
  }

  alarm_description = "[${upper(var.environment)}] EC2 CPU utilization exceeded ${var.ec2_cpu_threshold}% for 10 minutes"
  alarm_actions     = [aws_sns_topic.alerts[0].arn]
  ok_actions        = [aws_sns_topic.alerts[0].arn]

  tags = {
    Name = "${var.project_name}-ec2-cpu-alarm-${var.environment}"
  }
}

# EC2 Status Check Alarm (instance health)
# Triggers when ANY status check fails (system or instance) for 2 minutes
resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-ec2-status-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching" # Missing data = ALARM (if we can't check, assume bad)

  dimensions = {
    InstanceId = aws_instance.api.id
  }

  alarm_description = "[${upper(var.environment)}] EC2 instance status check failed"
  alarm_actions     = [aws_sns_topic.alerts[0].arn]
  ok_actions        = [aws_sns_topic.alerts[0].arn]

  tags = {
    Name = "${var.project_name}-ec2-status-alarm-${var.environment}"
  }
}
