terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "aws-landing-zone", ManagedBy = "terraform", Module = "monitoring" }
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region
  assume_role { role_arn = "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin" }
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
  assume_role { role_arn = "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin" }
}

# IAM role for cross-account log shipping
resource "aws_iam_role" "log_shipping" {
  name = "CloudWatchLogShippingRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
