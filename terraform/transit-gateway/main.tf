terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-landing-zone"
      ManagedBy = "terraform"
      Module    = "transit-gateway"
    }
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Transit Gateway — created in Management account, shared via RAM
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ec2_transit_gateway" "main" {
  description                     = "Landing Zone Hub — routes between Dev, Prod, and on-prem"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"   # needed for Direct Connect failover

  tags = { Name = "lz-transit-gateway" }
}

# ─────────────────────────────────────────────────────────────────────────────
# Resource Access Manager — share TGW with workload accounts
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ram_resource_share" "tgw" {
  name                      = "lz-tgw-share"
  allow_external_principals = false   # org-only sharing
  tags                      = { Name = "lz-tgw-share" }
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "dev" {
  principal          = var.dev_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "prod" {
  principal          = var.prod_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# TGW Attachments — Dev VPC
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.dev_vpc_id
  subnet_ids         = var.dev_private_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = { Name = "dev-tgw-attachment" }
}

# ─────────────────────────────────────────────────────────────────────────────
# TGW Attachments — Prod VPC (prod provider)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  provider           = aws.prod
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = { Name = "prod-tgw-attachment" }
}

# ─────────────────────────────────────────────────────────────────────────────
# Route table updates — add TGW route in each VPC's private route table
# "Send all RFC1918 traffic to TGW (catches dev ↔ prod cross-account traffic)"
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route" "dev_to_tgw" {
  route_table_id         = var.dev_private_route_table_id
  destination_cidr_block = "10.0.0.0/8"   # catches 10.1, 10.2, 10.3 in one rule
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.dev]
}

resource "aws_route" "prod_to_tgw" {
  provider               = aws.prod
  route_table_id         = var.prod_private_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.prod]
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulated on-prem connection — Virtual Private Gateway + Customer Gateway
# (Demonstrates Direct Connect / VPN knowledge — no real on-prem needed)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_customer_gateway" "onprem_sim" {
  bgp_asn    = 65000
  ip_address = "203.0.113.1"   # TEST-NET-3 — safe placeholder IP
  type       = "ipsec.1"
  tags       = { Name = "simulated-onprem-cgw", Note = "placeholder for Direct Connect demo" }
}

resource "aws_vpn_gateway" "prod_vgw" {
  provider        = aws.prod
  amazon_side_asn = 64513
  vpc_id          = var.prod_vpc_id
  tags            = { Name = "prod-vgw" }
}

# Note: aws_vpn_connection has a cost (~$0.05/hr) — kept commented out for free-tier safety
# Uncomment to demonstrate full VPN connectivity
#
# resource "aws_vpn_connection" "onprem_to_prod" {
#   provider            = aws.prod
#   vpn_gateway_id      = aws_vpn_gateway.prod_vgw.id
#   customer_gateway_id = aws_customer_gateway.onprem_sim.id
#   type                = "ipsec.1"
#   static_routes_only  = false
#   tags                = { Name = "onprem-to-prod-vpn" }
# }
