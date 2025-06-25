variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for Bastion Host"
  type        = string
  default     = "mcp_key_pair"  # .pem 확장자는 제외
}
