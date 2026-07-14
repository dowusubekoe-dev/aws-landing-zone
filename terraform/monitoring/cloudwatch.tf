# ── CloudWatch Alarm — triggers DR failover ───────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "prod_ec2_status_check" {
  provider            = aws.prod
  alarm_name          = "prod-ec2-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers DR ASG scale-up in us-west-2 when prod EC2 health checks fail"
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]
  tags                = { Name = "prod-ec2-status-check", Purpose = "dr-trigger" }
  dimensions          = { AutoScalingGroupName = "prod-app-asg" }
}

# ── SNS Topic ─────────────────────────────────────────────────────────────────
resource "aws_sns_topic" "ops_alerts" {
  name = "landing-zone-ops-alerts"
  tags = { Name = "ops-alerts" }
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.ops_email
}

# ── DR Pilot Light ASG ────────────────────────────────────────────────────────
resource "aws_launch_template" "dr_app" {
  provider      = aws.dr
  name_prefix   = "dr-pilot-light-"
  image_id      = var.dr_ami_id
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "dr-pilot-light-instance"
      Environment = "dr"
    }
  }
}

resource "aws_autoscaling_group" "dr_pilot_light" {
  provider            = aws.dr
  name                = "dr-pilot-light-asg"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0
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
    ignore_changes = [desired_capacity]
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "landing_zone" {
  dashboard_name = "LandingZone-OpsOverview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Prod EC2 CPU Utilization"
          region  = var.aws_region
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "prod-app-asg"]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DR ASG Capacity (us-west-2)"
          region  = "us-west-2"
          metrics = [["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "dr-pilot-light-asg"]]
          period  = 300
          stat    = "Maximum"
          view    = "timeSeries"
        }
      }
    ]
  })
}
