# 각 IAM Role의 ARN과 이름을 출력
output "eks_cluster_role_arn"  { value = aws_iam_role.eks_cluster.arn }
output "eks_cluster_role_name" { value = aws_iam_role.eks_cluster.name }
output "eks_worker_role_arn"   { value = aws_iam_role.eks_worker.arn }
output "eks_worker_role_name"  { value = aws_iam_role.eks_worker.name }
output "bastion_role_name"     { value = aws_iam_role.bastion.name }