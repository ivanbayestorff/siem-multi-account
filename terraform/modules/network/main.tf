variable "name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "az_id" {
  type = string
}

variable "region" {
  type = string
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "public" {
  vpc_id               = aws_vpc.this.id
  cidr_block           = cidrsubnet(var.cidr, 8, 0)
  availability_zone_id = var.az_id
  tags                 = { Name = "${var.name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id               = aws_vpc.this.id
  cidr_block           = cidrsubnet(var.cidr, 8, 1)
  availability_zone_id = var.az_id
  tags                 = { Name = "${var.name}-private" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = var.name }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.private.id]
  tags            = { Name = "${var.name}-s3" }
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "cidr" {
  value = var.cidr
}

output "private_subnet_id" {
  value      = aws_subnet.private.id
  depends_on = [aws_route.private_nat, aws_route_table_association.private]
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}
