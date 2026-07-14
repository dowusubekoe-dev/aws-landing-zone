variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "management_account_id" {
  type = string
}

variable "dev_account_id" {
  type = string
}

variable "prod_account_id" {
  type = string
}

# Passed in from account-baseline outputs
variable "dev_vpc_id" {
  description = "Dev VPC ID — from account-baseline output"
  type        = string
}

variable "dev_private_subnet_ids" {
  description = "Dev private subnet IDs for TGW attachment"
  type        = list(string)
}

variable "dev_private_route_table_id" {
  description = "Dev private route table ID — TGW route will be added here"
  type        = string
}

variable "prod_vpc_id" {
  description = "Prod VPC ID — from account-baseline output"
  type        = string
}

variable "prod_private_subnet_ids" {
  description = "Prod private subnet IDs for TGW attachment"
  type        = list(string)
}

variable "prod_private_route_table_id" {
  description = "Prod private route table ID — TGW route will be added here"
  type        = string
}
