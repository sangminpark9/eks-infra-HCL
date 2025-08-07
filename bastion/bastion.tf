# Bastion 호스트용 보안 그룹: SSH(22) 포트 인바운드 허용
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from internet to Bastion"
  vpc_id      = var.vpc_id

  # SSH 인바운드(예: 0.0.0.0/0 또는 관리자 IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]  # 변수로 외부 허용 CIDR 설정 (예: "0.0.0.0/0")
  }
  # 아웃바운드 전체 허용 (필요시 제한 가능)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# (옵션) Bastion 역할이 있다면 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = var.bastion_role_name  # IAM 모듈에서 전달된 Bastion 역할 이름
}

# Bastion Host EC2 인스턴스: 퍼블릭 서브넷에 생성, SSH 키로 접근
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = element(var.public_subnet_ids, 0)  # 첫 번째 퍼블릭 서브넷 사용
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  # (옵션) IAM 역할 부여
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  tags = { Name = "bastion-host" }
}
