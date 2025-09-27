resource "aws_vpc" "main" {
   cidr_block = var.vpc_cidr
   tags =  merge(var.tags, {Name="main-vpc"})
}

resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags, {Name = "main-igw"})
}

resource "aws_egress_only_internet_gateway" "my-egress-igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags,{name = "main-egress-igw"} )
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.main.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }

  route{
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id =  aws_egress_only_internet_gateway.my-egress-igw.id
  }
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = each.value
  map_public_ip_on_launch = var.enable_public_ip
  tags = merge(var.tags, {Name = "public-subnet-${each.key}"})
}


resource "aws_route_table_association" "public-assoc" {
     for_each = aws_subnet.public
     subnet_id = each.value.id
     route_table_id = aws_route_table.prod-route-table.id
}

