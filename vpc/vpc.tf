variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "outpost_subnet_cidrs" {
  default = ["10.0.100.0/26", "10.0.100.64/26"]
}

variable "outpost_arn" {
  description = "Outposts ARN"
  type        = string
}

# 가용 영역 조회 (퍼블릭 서브넷에 사용)
data "aws_availability_zones" "available" {}

# VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "outposts-vpc" }
}

# 인터넷 게이트웨이 (Bastion 용)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "vpc-igw" }
}

# 퍼블릭 서브넷 (리전용, Bastion 등)
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# 퍼블릭 라우트 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

# 퍼블릭 서브넷 라우트 연결
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Outposts 전용 서브넷 (EKS, EC2)
resource "aws_subnet" "outposts" {
  count             = length(var.outpost_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.outpost_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # 핵심!
  outpost_arn       = var.outpost_arn

  map_public_ip_on_launch = false

  tags = {
    Name = "outposts-subnet-${count.index}"
  }
}
