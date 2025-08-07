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
