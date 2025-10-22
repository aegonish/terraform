#########################################
# VPC + Subnets + Routing for EKS
#########################################

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.cluster_name}-vpc" })
}

#########################################
# Internet Gateway for Public Access
#########################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.cluster_name}-igw" })
}

#########################################
# Public Subnets
#########################################
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnets : idx => cidr }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = element(var.azs, tonumber(each.key) % length(var.azs))
  tags = merge(var.tags, {
    Name                        = "${var.cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb"    = "1"
  })
}

#########################################
# Private Subnets
#########################################
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnets : idx => cidr }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  availability_zone       = element(var.azs, tonumber(each.key) % length(var.azs))
  tags = merge(var.tags, {
    Name                         = "${var.cluster_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

#########################################
# NAT Gateway for Private Subnets
#########################################

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(var.tags, { Name = "${var.cluster_name}-nat-eip" })
}

# Create NAT Gateway in the first public subnet
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.this]
  tags = merge(var.tags, { Name = "${var.cluster_name}-nat-gw" })
}

#########################################
# Route Tables
#########################################

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.cluster_name}-public-rt" })
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.cluster_name}-private-rt" })
}

#########################################
# Route Table Associations
#########################################
resource "aws_route_table_association" "public_assoc" {
  for_each      = aws_subnet.public
  subnet_id     = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc" {
  for_each      = aws_subnet.private
  subnet_id     = each.value.id
  route_table_id = aws_route_table.private.id
}

#########################################
# Security group for EKS control plane
#########################################
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.cluster_name}-cluster-sg" })

  ingress {
    description = "Allow all inbound from same security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
