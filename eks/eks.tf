# EKS 클러스터 생성: 외부에서 전달된 역할 ARN 사용
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn  # IAM 모듈에서 전달된 클러스터 역할 ARN
  version = var.cluster_version
  vpc_config {
    subnet_ids = var.subnet_ids     # VPC 모듈에서 전달된 서브넷 리스트
    # (추가로 보안 그룹을 지정할 수 있음)
  }
}

# (선택사항) EKS 노드 그룹: 워커노드 역할 ARN 사용
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  version = var.cluster_version
  node_group_name = var.node_group_name
  node_role_arn   = var.worker_role_arn  # IAM 모듈에서 전달된 워커 역할 ARN
  subnet_ids      = var.subnet_ids
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
