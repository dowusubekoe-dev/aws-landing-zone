# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch — Centralized log destination in Log Archive account
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "prod_app" {
  provider          = aws.prod
  name              = "/prod/application"
  retention_in_days = 90
  tags              = { Name = "prod-app-logs" }
}

# Cross-account log destination in Log Archive account
resource "aws_cloudwatch_log_destination" "central_log" {
  name       = "central-log-destination"
  role_arn   = aws_iam_role.log_shipping.arn
  target_arn = aws_kinesis_firehose_delivery_stream.log_archive.arn   # see ssm.tf
}

resource "aws_cloudwatch_log_destination_policy" "central_log" {
  destination_name = aws_cloudwatch_log_destination.central_log.name
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = [var.dev_account_id, var.prod_account_id] }
      Action    = "logs:PutSubscriptionFilter"
      Resource  = aws_cloudwatch_log_destination.central_log.arn
    }]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Alarms — Prod EC2 health (triggers DR failover)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "prod_ec2_status_check" {
  provider            = aws.prod
  alarm_name          = "prod-ec2-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300   # 5 minutes
  statistic           = "Maximum"
  threshold           = 1

  alarm_description = "Triggers DR ASG scale-up in us-west-2 when prod EC2 health checks fail"
  alarm_actions     = [aws_sns_topic.ops_alerts.arn]
  ok_actions        = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    AutoScalingGroupName = "prod-app-asg"
  }

  tags = { Name = "prod-ec2-status-check", Purpose = "dr-trigger" }
}

resource "aws_cloudwatch_metric_alarm" "prod_cpu_high" {
  provider            = aws.prod
  alarm_name          = "prod-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description = "Prod CPU above 80% for 15 minutes"
  alarm_actions     = [aws_sns_topic.ops_alerts.arn]

  tags = { Name = "prod-cpu-high" }
}

# ─────────────────────────────────────────────────────────────────────────────
# SNS Topic — ops alerts
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "ops_alerts" {
  name = "landing-zone-ops-alerts"
  tags = { Name = "ops-alerts" }
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.ops_email
}

# ─────────────────────────────────────────────────────────────────────────────
# DR Auto Scaling Group — Pilot Light in us-west-2
# min=0, desired=0 normally; alarm scales it to desired=2
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_launch_template" "dr_app" {
  provider      = aws.dr
  name_prefix   = "dr-pilot-light-"
  image_id      = var.dr_ami_id           # AMI copied from prod (set in tfvars)
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "dr-pilot-light-instance", Environment = "dr" }
  }
}

resource "aws_autoscaling_group" "dr_pilot_light" {
  provider            = aws.dr
  name                = "dr-pilot-light-asg"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0                  # stays at 0 until DR triggered
  vpc_zone_identifier = var.dr_private_subnet_ids

  launch_template {
    id      = aws_launch_template.dr_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "dr-pilot-light"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]   # allow alarm to scale without TF drift
  }
}

# CloudWatch alarm action — scale DR ASG to 2 when prod fails
resource "aws_autoscaling_policy" "dr_scale_out" {
  provider               = aws.dr
  name                   = "dr-scale-out-on-prod-failure"
  autoscaling_group_name = aws_autoscaling_group.dr_pilot_light.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ExactCapacity"
  scaling_adjustment     = 2
  cooldown               = 300
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Dashboard — Ops overview
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "landing_zone" {
  dashboard_name = "LandingZone-OpsOverview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width = 12
        height = 6
        properties = {
          title  = "Prod EC2 CPU Utilization"
          region = var.aws_region
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "prod-app-asg"]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type = "metric"
        x    = 12
        y    = 0
        width = 12
        height = 6
        properties = {
          title  = "Prod EC2 Status Check"
          region = var.aws_region
          metrics = [["AWS/EC2", "StatusCheckFailed", "AutoScalingGroupName", "prod-app-asg"]]
          period  = 300
          stat    = "Maximum"
          view    = "timeSeries"
        }
      },
      {
        type = "metric"
        x    = 0
        y    = 6
        width = 12
        height = 6
        properties = {
          title  = "DR ASG Capacity (us-west-2)"
          region = "us-west-2"
          metrics = [["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "dr-pilot-light-asg"]]
          period  = 300
          stat    = "Maximum"
          view    = "timeSeries"
          annotations = { horizontal = [{ value = 1, label = "DR Active", color = "#ff5252" }] }
        }
      }
    ]
  })
}
