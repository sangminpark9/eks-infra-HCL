# security.tf
# EKS 클러스터 보안 그룹 설정 - AWS 베스트 프랙티스 준수
#
# 포트 10250 (kubelet API): 
# - AWS 권장사항에 따라 클러스터가 워커 노드의 kubelet API와 통신하는 전용 포트
# - 기존 1025-65535 대신 특정 포트만 허용하여 보안 강화 (최소 권한 원칙)
# - kubelet 상태 확인, Pod 생성/삭제, 로그 수집, exec 명령 실행 등에 사용
#
# DNS 통신 (포트 53):
# - 워커 노드가 AWS 서비스 엔드포인트 해석 및 컨테이너 이미지 레지스트리 접근을 위해 필수
# - ECR, EKS API, 기타 AWS 서비스 도메인 해석에 필요
# - UDP/TCP 모두 지원하지만 주로 UDP 사용

# 클러스터 제어 플레인용 보안 그룹
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# 노드 그룹용 보안 그룹
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-sg"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

# 보안 그룹 규칙 - 노드 -> 클러스터 (API 서버 통신)
resource "aws_security_group_rule" "cluster_ingress_from_node" {
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow worker nodes to communicate with cluster API Server"
}

# 보안 그룹 규칙 - 클러스터 -> 노드 (kubelet API 통신)
resource "aws_security_group_rule" "node_ingress_from_cluster_kubelet" {
  type                     = "ingress"
  from_port               = 10250
  to_port                 = 10250
  protocol                = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
  description              = "Allow cluster to communicate with kubelet API"
}

# 보안 그룹 규칙 - 노드 간 통신 (Pod-to-Pod, 서비스 디스커버리)
resource "aws_security_group_rule" "node_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.node_group.id
  description       = "Allow nodes to communicate with each other"
}

# 보안 그룹 규칙 - DNS 해석 (UDP)
resource "aws_security_group_rule" "node_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group.id
  description       = "Allow DNS resolution via UDP"
}

# 보안 그룹 규칙 - DNS 해석 (TCP)
resource "aws_security_group_rule" "node_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group.id
  description       = "Allow DNS resolution via TCP"
}