variable "aws_region"            { type = string; default = "us-east-1" }
variable "prod_account_id"       { type = string }
variable "dev_account_id"        { type = string }
variable "ops_email"             { type = string; description = "Email for ops SNS alerts" }
variable "config_bucket_name"    { type = string; description = "S3 bucket in Log Archive account for Config/SSM output" }
variable "dr_ami_id"             { type = string; description = "AMI ID copied to us-west-2 for Pilot Light" }
variable "dr_private_subnet_ids" { type = list(string); description = "DR VPC private subnet IDs in us-west-2" }
variable "prod_db_endpoint"      { type = string; sensitive = true; description = "RDS endpoint for SSM Parameter Store" }
