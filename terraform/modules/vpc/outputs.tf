output "vpc_id" {
  value = aws_vpc.sentinel_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.sentinel_vpc.cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_route_table_id" {
  value = aws_route_table.private_rt.id
}

output "public_route_table_id" {
  value = aws_route_table.public_rt.id
}

output "nat_gateway_id" {
  value = var.enable_nat_gateway ? aws_nat_gateway.sentinel_nat[0].id : null
}

output "internet_gateway_id" {
  value = aws_internet_gateway.sentinel_igw.id
}
