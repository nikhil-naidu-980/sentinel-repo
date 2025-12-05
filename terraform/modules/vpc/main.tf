terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_availability_zones" "region_azs" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.region_azs.names, 0, 2)
}

# VPC Core Infrastructure
resource "aws_vpc" "sentinel_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = var.vpc_name })
}

resource "aws_internet_gateway" "sentinel_igw" {
  vpc_id = aws_vpc.sentinel_vpc.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-igw" })
}

# Subnets - Public and Private across AZs
resource "aws_subnet" "public_subnet" {
  count                   = length(local.selected_azs)
  vpc_id                  = aws_vpc.sentinel_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.selected_azs[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, {
    Name                     = "${var.vpc_name}-public-${local.selected_azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private_subnet" {
  count             = length(local.selected_azs)
  vpc_id            = aws_vpc.sentinel_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = local.selected_azs[count.index]
  tags = merge(var.tags, {
    Name                              = "${var.vpc_name}-private-${local.selected_azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# NAT Gateway for Private Subnet Outbound Traffic
resource "aws_eip" "nat_eip" {
  count      = var.enable_nat_gateway ? 1 : 0
  domain     = "vpc"
  tags       = merge(var.tags, { Name = "${var.vpc_name}-nat-eip" })
  depends_on = [aws_internet_gateway.sentinel_igw]
}

resource "aws_nat_gateway" "sentinel_nat" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public_subnet[0].id
  tags          = merge(var.tags, { Name = "${var.vpc_name}-nat" })
  depends_on    = [aws_internet_gateway.sentinel_igw]
}

# Route Tables - Public and Private
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sentinel_vpc.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-public-rt" })
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sentinel_igw.id
}

resource "aws_route_table_association" "public_subnet_assoc" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.sentinel_vpc.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-private-rt" })
}

resource "aws_route" "private_nat_route" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.sentinel_nat[0].id
}

resource "aws_route_table_association" "private_subnet_assoc" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# VPC Flow Logs for Network Monitoring
resource "aws_flow_log" "vpc_flow_log" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_log_role[0].arn
  log_destination_type = "cloud-watch-logs"
  log_group_name       = "/aws/vpc-flow-logs/${aws_vpc.sentinel_vpc.id}"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.sentinel_vpc.id
  tags                 = merge(var.tags, { Name = "${var.vpc_name}-flow-logs" })
}

resource "aws_iam_role" "flow_log_role" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "flow_log_policy" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-logs-policy"
  role  = aws_iam_role.flow_log_role[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}
