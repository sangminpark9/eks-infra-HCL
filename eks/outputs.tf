# EKS 클러스터의 컨트롤 플레인 보안 그룹 ID 출력
output "eks_cluster_security_group_id" {
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description = "EKS에서 자동 생성된 클러스터 SG ID"
}

