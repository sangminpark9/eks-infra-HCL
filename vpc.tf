# 사용 가능한 가용영역 정보 조회
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC 생성 - 10.0.0.0/16 CIDR 블록 사용
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true  # DNS 호스트명 지원 활성화
  enable_dns_support   = true  # DNS 확인 지원 활성화

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"  # EKS 클러스터용 태그
  }
}

# Internet Gateway 생성
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# NAT Gateway용 Elastic IP 생성
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# 단일 퍼블릭 서브넷 생성 - 첫 번째 가용영역에 배치
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"  # 256개 IP 주소 할당
  availability_zone       = data.aws_availability_zones.available.names[0]  # 첫 번째 AZ 사용
  map_public_ip_on_launch = true  # 인스턴스 시작 시 자동으로 퍼블릭 IP 할당

  tags = {
    Name                                        = "${var.cluster_name}-public-1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                   = "1"  # 외부 로드밸런서용 서브넷 표시
  }
}

# 프라이빗 서브넷 3개 생성 - 각각 다른 가용영역에 배치
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"  # 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                         = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}"  = "owned"  # EKS가 소유하는 서브넷
    "kubernetes.io/role/internal-elb"           = "1"  # 내부 로드밸런서용 서브넷 표시
  }
}

# NAT Gateway 생성 - 퍼블릭 서브넷에 배치
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  tags = {
    Name = "${var.cluster_name}-nat"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# 퍼블릭 서브넷용 라우팅 테이블 - 모든 트래픽을 IGW로 라우팅
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# 프라이빗 서브넷용 라우팅 테이블 - 모든 트래픽을 NAT Gateway로 라우팅
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"              # 모든 외부 트래픽
    nat_gateway_id = aws_nat_gateway.main.id  # NAT Gateway로 라우팅
  }
  
  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# 퍼블릭 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 모든 프라이빗 서브넷을 같은 라우팅 테이블에 연결
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}