output "vpc_id" {
    description = "the ID of the created VPC"
    value = aws_vpc.main.id
}

output "public_subnet_ids"{
    description = "List of public subnet IDs"
    value = [for subnet in aws_subnet.public : subnet.id]
}

output "route_table_id" {
    description = "Route table for public subnets"
    value = aws_route_table.prod-route-table.id
}

output "igw_id" {
    description = "Internet Gateway ID"
    value = aws_internet_gateway.my-igw.id
}
