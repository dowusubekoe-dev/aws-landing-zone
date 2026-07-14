# ─────────────────────────────────────────────────────────────────────────────
# SSM Patch Manager — automated patching baseline
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ssm_patch_baseline" "amazon_linux_2" {
  provider         = aws.prod
  name             = "lz-amazon-linux-2-baseline"
  description      = "Landing Zone patch baseline — Critical and Important patches for Amazon Linux 2"
  operating_system = "AMAZON_LINUX_2"

  approval_rule {
    approve_after_days  = 7     # auto-approve after 7 days; reduces risk vs immediate
    enable_non_security = false

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  tags = { Name = "lz-amazon-linux-2-baseline" }
}

# Register as the default baseline for Amazon Linux 2
resource "aws_ssm_default_patch_baseline" "amazon_linux_2" {
  provider         = aws.prod
  baseline_id      = aws_ssm_patch_baseline.amazon_linux_2.id
  operating_system = "AMAZON_LINUX_2"
}

# Maintenance window — patch every Sunday at 02:00 UTC
resource "aws_ssm_maintenance_window" "weekly_patching" {
  provider          = aws.prod
  name              = "lz-weekly-patching"
  schedule          = "cron(0 2 ? * SUN *)"
  duration          = 2     # hours
  cutoff            = 1     # stop registering new tasks 1hr before end
  allow_unassociated_targets = false

  tags = { Name = "lz-weekly-patching" }
}

resource "aws_ssm_maintenance_window_target" "prod_instances" {
  provider      = aws.prod
  window_id     = aws_ssm_maintenance_window.weekly_patching.id
  name          = "prod-instances"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Environment"
    values = ["prod"]
  }
}

resource "aws_ssm_maintenance_window_task" "run_patch_baseline" {
  provider         = aws.prod
  window_id        = aws_ssm_maintenance_window.weekly_patching.id
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_maintenance.arn
  max_concurrency  = "50%"
  max_errors       = "20%"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.prod_instances.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      timeout_seconds  = 600
      output_s3_bucket = var.config_bucket_name

      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SSM Parameter Store — app config stored as SecureString
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "db_endpoint" {
  provider    = aws.prod
  name        = "/prod/app/db-endpoint"
  description = "Production RDS endpoint — referenced by app at runtime"
  type        = "SecureString"
  value       = var.prod_db_endpoint    # passed in via tfvars, never hardcoded

  tags = { Name = "prod-db-endpoint", Environment = "prod" }
}

resource "aws_ssm_parameter" "environment_name" {
  provider    = aws.prod
  name        = "/prod/app/environment"
  description = "Environment identifier consumed by app config"
  type        = "String"
  value       = "production"

  tags = { Name = "prod-environment", Environment = "prod" }
}

resource "aws_ssm_parameter" "app_version" {
  provider    = aws.prod
  name        = "/prod/app/version"
  description = "Current deployed app version — updated by CI/CD pipeline on deploy"
  type        = "String"
  value       = "1.0.0"

  lifecycle {
    ignore_changes = [value]   # CI pipeline owns this value after initial creation
  }
}

# ── IAM Role for SSM Maintenance Window ──────────────────────────────────────
resource "aws_iam_role" "ssm_maintenance" {
  provider = aws.prod
  name     = "SSMMaintenanceWindowRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance" {
  provider   = aws.prod
  role       = aws_iam_role.ssm_maintenance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}
