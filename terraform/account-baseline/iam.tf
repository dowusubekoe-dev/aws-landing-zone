# ─────────────────────────────────────────────────────────────────────────────
# Cross-Account IAM Role — allows Management account to assume into workload accounts
# ─────────────────────────────────────────────────────────────────────────────

# This role is created IN the Dev account (primary provider)
resource "aws_iam_role" "landing_zone_admin_dev" {
  name        = "LandingZoneAdmin"
  description = "Allows Management account Terraform/CI to administer Dev account resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManagementAccountAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          # Only allow assumption from specific IAM entities (least privilege)
          ArnLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${var.management_account_id}:role/TerraformExecutionRole",
              "arn:aws:iam::${var.management_account_id}:role/GitHubActionsRole"
            ]
          }
        }
      }
    ]
  })

  tags = { Name = "LandingZoneAdmin", Purpose = "cross-account-terraform" }
}

resource "aws_iam_role_policy_attachment" "landing_zone_admin_dev" {
  role       = aws_iam_role.landing_zone_admin_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  # Note: In production, replace with a least-privilege custom policy
}

# ─────────────────────────────────────────────────────────────────────────────
# Cross-Account Role — Prod account (created via prod provider)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "landing_zone_admin_prod" {
  provider    = aws.prod
  name        = "LandingZoneAdmin"
  description = "Allows Management account Terraform/CI to administer Prod account resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManagementAccountAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          ArnLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${var.management_account_id}:role/TerraformExecutionRole",
              "arn:aws:iam::${var.management_account_id}:role/GitHubActionsRole"
            ]
          }
        }
      }
    ]
  })

  tags = { Name = "LandingZoneAdmin", Purpose = "cross-account-terraform" }
}

resource "aws_iam_role_policy_attachment" "landing_zone_admin_prod" {
  provider   = aws.prod
  role       = aws_iam_role.landing_zone_admin_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions IAM Role — Management account (OIDC-based, no static keys)
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name        = "GitHubActionsRole"
  description = "Role assumed by GitHub Actions via OIDC — no static AWS keys needed"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Restrict to YOUR repo — replace with your GitHub username
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/aws-landing-zone:*"
          }
        }
      }
    ]
  })

  tags = { Name = "GitHubActionsRole", Purpose = "ci-cd" }
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "GitHubActionsPolicy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = [
          "arn:aws:iam::${var.dev_account_id}:role/LandingZoneAdmin",
          "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin"
        ]
      },
      {
        # Terraform state bucket access
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::your-landing-zone-tfstate",
          "arn:aws:s3:::your-landing-zone-tfstate/*"
        ]
      },
      {
        # DynamoDB state lock
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:us-east-1:${var.management_account_id}:table/terraform-state-lock"
      }
    ]
  })
}
