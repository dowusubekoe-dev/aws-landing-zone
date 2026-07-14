# ─────────────────────────────────────────────────────────────────────────────
# VPC — Dev Account (primary provider)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "dev" {
  cidr_block           = var.dev_vpc_cidr   # 10.1.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "dev-workload-vpc" }
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "dev-igw" }
}

# Public subnets — one per AZ
resource "aws_subnet" "dev_public" {
  count             = 2
  vpc_id            = aws_vpc.dev.id
  cidr_block        = cidrsubnet(var.dev_vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "dev-public-${count.index + 1}", Tier = "public" }
}

# Private subnets — one per AZ
resource "aws_subnet" "dev_private" {
  count             = 2
  vpc_id            = aws_vpc.dev.id
  cidr_block        = cidrsubnet(var.dev_vpc_cidr, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "dev-private-${count.index + 1}", Tier = "private" }
}

# Public route table
resource "aws_route_table" "dev_public" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  tags = { Name = "dev-public-rt" }
}

resource "aws_route_table_association" "dev_public" {
  count          = 2
  subnet_id      = aws_subnet.dev_public[count.index].id
  route_table_id = aws_route_table.dev_public.id
}

# Private route table — TGW route added in transit-gateway module
resource "aws_route_table" "dev_private" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "dev-private-rt" }
}

resource "aws_route_table_association" "dev_private" {
  count          = 2
  subnet_id      = aws_subnet.dev_private[count.index].id
  route_table_id = aws_route_table.dev_private.id
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC — Prod Account (prod provider)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "prod" {
  provider             = aws.prod
  cidr_block           = var.prod_vpc_cidr   # 10.2.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "prod-workload-vpc" }
}

resource "aws_internet_gateway" "prod" {
  provider = aws.prod
  vpc_id   = aws_vpc.prod.id
  tags     = { Name = "prod-igw" }
}

resource "aws_subnet" "prod_public" {
  provider          = aws.prod
  count             = 2
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "prod-public-${count.index + 1}", Tier = "public" }
}

resource "aws_subnet" "prod_private" {
  provider          = aws.prod
  count             = 2
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_vpc_cidr, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "prod-private-${count.index + 1}", Tier = "private" }
}

resource "aws_route_table" "prod_private" {
  provider = aws.prod
  vpc_id   = aws_vpc.prod.id
  tags     = { Name = "prod-private-rt" }
}

resource "aws_route_table_association" "prod_private" {
  provider       = aws.prod
  count          = 2
  subnet_id      = aws_subnet.prod_private[count.index].id
  route_table_id = aws_route_table.prod_private.id
}

# ─────────────────────────────────────────────────────────────────────────────
# DR VPC — Prod Account, us-west-2 (Pilot Light)
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "dr"
  region = "us-west-2"

  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/LandingZoneAdmin"
  }
}

resource "aws_vpc" "dr" {
  provider             = aws.dr
  cidr_block           = var.dr_vpc_cidr   # 10.3.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "dr-pilot-light-vpc", Region = "us-west-2" }
}

resource "aws_subnet" "dr_private" {
  provider          = aws.dr
  count             = 2
  vpc_id            = aws_vpc.dr.id
  cidr_block        = cidrsubnet(var.dr_vpc_cidr, 4, count.index + 4)
  availability_zone = "us-west-2${["a", "b"][count.index]}"

  tags = { Name = "dr-private-${count.index + 1}", Tier = "dr" }
}

# ─────────────────────────────────────────────────────────────────────────────
# Data sources
# ─────────────────────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}
