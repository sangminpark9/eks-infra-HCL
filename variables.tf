variable "bastion_ami" {
  description = "AMI ID to use for the Bastion host"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to access bastion host via SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "outpost_arn" {
  description = "ARN of the AWS Outpost to use"
  type        = string
}

variable "control_plane_instance_type" {
  description = "Instance type for EKS control plane on Outposts"
  type        = string
}

variable "outposts_instance_type" {
  description = "Instance type for EKS worker nodes on Outposts"
  type        = string
  default     = "m5d.outpost"  # 예시: Outposts 호환 인스턴스 타입
}
