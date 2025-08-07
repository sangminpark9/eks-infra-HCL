output "eks_cluster_id" {
  value       = aws_eks_cluster.main.id
  description = "The ID of the EKS cluster"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The endpoint for the EKS cluster"
}

output "eks_cluster_security_group_id" {
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description = "EKS 클러스터의 보안 그룹 ID"
}
