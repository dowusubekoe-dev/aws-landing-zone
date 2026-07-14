terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after creating your S3 state bucket + DynamoDB lock table
  # backend "s3" {
  #   bucket         = "your-landing-zone-tfstate"
  #   key            = "account-baseline/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

# ── Primary region provider (Management / Dev account) ────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-landing-zone"
      ManagedBy   = "terraform"
      Environment = var.environment
      Owner       = "derek-o"
    }
  }
}

# ── Prod account provider (cross-account via assumed role) ────────────────
provider "aws" {
  alias  = "prod"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin"
  }

  default_tags {
    tags = {
      Project     = "aws-landing-zone"
      ManagedBy   = "terraform"
      Environment = "prod"
      Owner       = "derek-o"
    }
  }
}
