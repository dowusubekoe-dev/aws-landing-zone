variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "prod_account_id" {
  description = "AWS Account ID of the Prod workload account"
  type        = string
}

variable "dev_account_id" {
  description = "AWS Account ID of the Dev workload account"
  type        = string
}

variable "ops_email" {
  description = "Email address for SNS ops alerts"
  type        = string
}

variable "config_bucket_name" {
  description = "S3 bucket in Log Archive account for Config and SSM output"
  type        = string
}

variable "dr_ami_id" {
  description = "AMI ID copied to us-west-2 for Pilot Light DR"
  type        = string
}

variable "dr_private_subnet_ids" {
  description = "List of private subnet IDs in the DR VPC (us-west-2)"
  type        = list(string)
}

variable "prod_db_endpoint" {
  description = "RDS endpoint stored in SSM Parameter Store"
  type        = string
  sensitive   = true
}
