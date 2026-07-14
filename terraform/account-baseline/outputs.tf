output "dev_vpc_id" {
  description = "ID of the Dev VPC"
  value       = aws_vpc.dev.id
}

output "dev_private_subnet_ids" {
  description = "List of private subnet IDs in the Dev VPC (used by Transit Gateway attachment)"
  value       = aws_subnet.dev_private[*].id
}

output "dev_public_subnet_ids" {
  description = "List of public subnet IDs in the Dev VPC"
  value       = aws_subnet.dev_public[*].id
}

output "dev_private_route_table_id" {
  description = "Route table ID for Dev private subnets (TGW route added by transit-gateway module)"
  value       = aws_route_table.dev_private.id
}

output "prod_vpc_id" {
  description = "ID of the Prod VPC"
  value       = aws_vpc.prod.id
}

output "prod_private_subnet_ids" {
  description = "List of private subnet IDs in the Prod VPC"
  value       = aws_subnet.prod_private[*].id
}

output "prod_private_route_table_id" {
  description = "Route table ID for Prod private subnets"
  value       = aws_route_table.prod_private.id
}

output "dr_vpc_id" {
  description = "ID of the DR VPC in us-west-2"
  value       = aws_vpc.dr.id
}

output "dr_private_subnet_ids" {
  description = "List of private subnet IDs in the DR VPC"
  value       = aws_subnet.dr_private[*].id
}

output "landing_zone_admin_role_arn_dev" {
  description = "ARN of the LandingZoneAdmin role in the Dev account"
  value       = aws_iam_role.landing_zone_admin_dev.arn
}

output "landing_zone_admin_role_arn_prod" {
  description = "ARN of the LandingZoneAdmin role in the Prod account"
  value       = aws_iam_role.landing_zone_admin_prod.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role (use this in your workflow secrets)"
  value       = aws_iam_role.github_actions.arn
}
