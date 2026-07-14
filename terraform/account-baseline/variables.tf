variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod", "sandbox"], var.environment)
    error_message = "environment must be one of: dev, prod, sandbox"
  }
}

variable "management_account_id" {
  description = "AWS Account ID of the Management/root account"
  type        = string
}

variable "dev_account_id" {
  description = "AWS Account ID of the Dev workload account"
  type        = string
}

variable "prod_account_id" {
  description = "AWS Account ID of the Prod workload account"
  type        = string
}

variable "dev_vpc_cidr" {
  description = "CIDR block for the Dev VPC — must not overlap with prod or DR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "prod_vpc_cidr" {
  description = "CIDR block for the Prod VPC — must not overlap with dev or DR"
  type        = string
  default     = "10.2.0.0/16"
}

variable "dr_vpc_cidr" {
  description = "CIDR block for the DR VPC in us-west-2 — must not overlap with dev or prod"
  type        = string
  default     = "10.3.0.0/16"
}
