output "bastion_public_ip" {
  value       = module.bastion.bastion_public_ip
  description = "Bastion 호스트의 퍼블릭 IP"
}

output "eks_cluster_security_group_id" {
  value       = module.eks.eks_cluster_security_group_id
  description = "EKS 클러스터의 보안 그룹 ID"
}