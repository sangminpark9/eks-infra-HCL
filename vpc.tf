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

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
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

# 프라이빗 서브넷 3개 생성 - 각각 다른 가용영역
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

# 단일 NAT Gateway 생성 - 프라이빗 서브넷에서 인터넷 접근을 위함
# 퍼블릭 서브넷에 위치하여 자동으로 퍼블릭 IP 할당
resource "aws_nat_gateway" "main" {
  subnet_id = aws_subnet.public.id    # 퍼블릭 서브넷에 배치
  tags = {
    Name = "${var.cluster_name}-nat"
  }
  depends_on = [aws_internet_gateway.main]  # IGW 생성 후에 생성
}

# 퍼블릭 서브넷용 라우팅 테이블 - 모든 트래픽을 IGW로 라우팅
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id   # 인터넷 게이트웨이로 라우팅
  }
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# 퍼블릭 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 프라이빗 서브넷용 단일 라우팅 테이블 - 모든 트래픽을 NAT Gateway로 라우팅
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

# 모든 프라이빗 서브넷을 같은 라우팅 테이블에 연결
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================
# Bastion Host 구성
# =============================================================

# 최신 Amazon Linux 2 AMI 조회
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host용 보안 그룹 생성
resource "aws_security_group" "bastion" {
  name_prefix = "${var.cluster_name}-bastion-"
  vpc_id      = aws_vpc.main.id

  # SSH 접근 허용 (필요에 따라 source IP 제한 가능)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 보안상 특정 IP로 제한하는 것을 권장
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-bastion-sg"
  }
}

# Bastion Host용 EIP 생성
resource "aws_eip" "bastion" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags = {
    Name = "${var.cluster_name}-bastion-eip"
  }
}

# Bastion Host EC2 인스턴스 생성
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"  # 프리티어 가능
  key_name               = var.key_pair_name  # variables.tf에서 정의 필요
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = aws_subnet.public.id

  # 사용자 데이터 - 기본 패키지 업데이트 및 유용한 도구 설치
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y htop tree wget curl
              # kubectl 설치 (옵션)
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/
              EOF

  tags = {
    Name = "${var.cluster_name}-bastion"
  }
}

# Bastion Host에 EIP 연결
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
