output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "ram_share_arn" {
  description = "ARN of the RAM resource share"
  value       = aws_ram_resource_share.tgw.arn
}

output "dev_tgw_attachment_id" {
  description = "ID of the Dev VPC TGW attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.dev.id
}

output "prod_tgw_attachment_id" {
  description = "ID of the Prod VPC TGW attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.prod.id
}
