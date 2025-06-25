# security.tf
# 클러스터 및 노드 그룹에 필요한 보안 그룹 정의

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

# 보안 그룹 규칙 - 클러스터 -> 노드
resource "aws_security_group_rule" "cluster_ingress_from_node" {
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow worker nodes to communicate with cluster API Server"
}

# 보안 그룹 규칙 - 노드 -> 클러스터
resource "aws_security_group_rule" "node_ingress_from_cluster" {
  type                     = "ingress"
  from_port               = 1025
  to_port                 = 65535
  protocol                = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
  description              = "Allow pods to receive communication from the control plane"
}

# 보안 그룹 규칙 - 노드 간 통신
resource "aws_security_group_rule" "node_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.node_group.id
  description       = "Allow nodes to communicate with each other"
}
