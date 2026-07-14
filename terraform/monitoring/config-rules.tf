# ─────────────────────────────────────────────────────────────────────────────
# AWS Config — Compliance rules across workload accounts
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "prod" {
  provider = aws.prod
  name     = "prod-config-recorder"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  role_arn = aws_iam_role.config_recorder.arn
}

resource "aws_config_delivery_channel" "prod" {
  provider       = aws.prod
  name           = "prod-config-delivery"
  s3_bucket_name = var.config_bucket_name # created in Log Archive account

  depends_on = [aws_config_configuration_recorder.prod]
}

resource "aws_config_configuration_recorder_status" "prod" {
  provider   = aws.prod
  name       = aws_config_configuration_recorder.prod.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.prod]
}

# ── Managed rule: S3 public read prohibited ──────────────────────────────────
resource "aws_config_config_rule" "s3_public_read_prohibited" {
  provider = aws.prod
  name     = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.prod]
}

# ── Managed rule: Restrict SSH access ────────────────────────────────────────
resource "aws_config_config_rule" "restricted_ssh" {
  provider = aws.prod
  name     = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.prod]
}

# ── Managed rule: MFA on root account ────────────────────────────────────────
resource "aws_config_config_rule" "mfa_enabled_for_iam_console" {
  provider = aws.prod
  name     = "mfa-enabled-for-iam-console-access"

  source {
    owner             = "AWS"
    source_identifier = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
  }

  depends_on = [aws_config_configuration_recorder_status.prod]
}

# ── Managed rule: Encrypted EBS volumes ──────────────────────────────────────
resource "aws_config_config_rule" "encrypted_volumes" {
  provider = aws.prod
  name     = "encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder_status.prod]
}

# ── IAM role for Config recorder ─────────────────────────────────────────────
resource "aws_iam_role" "config_recorder" {
  provider = aws.prod
  name     = "AWSConfigRecorderRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_recorder" {
  provider   = aws.prod
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
