# EKS 클러스터용 IAM 역할 생성
# EKS 서비스가 클러스터를 관리하기 위해 필요한 권한을 제공
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  # EKS 서비스가 이 역할을 assume할 수 있도록 허용하는 정책
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"  # EKS 서비스만 이 역할을 사용할 수 있음
      }
    }]
  })
}

# EKS 클러스터 역할에 AWS 관리형 정책 연결
# 클러스터 운영에 필요한 기본 권한을 제공 (VPC, 서브넷, 보안그룹 관리 등)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS 노드 그룹용 IAM 역할 생성
# 워커 노드(EC2 인스턴스)가 EKS 클러스터에 조인하기 위해 필요
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  # EC2 서비스가 이 역할을 assume할 수 있도록 허용하는 정책
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"  # EC2 인스턴스가 이 역할을 사용할 수 있음
      }
    }]
  })
}

# 노드 그룹 역할에 워커 노드 정책 연결
# EKS 클러스터에 노드가 조인하고 통신하기 위한 기본 권한 제공
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# 노드 그룹 역할에 CNI 정책 연결
# 포드 네트워킹을 위한 ENI(Elastic Network Interface) 관리 권한 제공
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# 노드 그룹 역할에 ECR 읽기 전용 정책 연결
# 컨테이너 이미지를 ECR에서 pull하기 위한 권한 제공
resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}