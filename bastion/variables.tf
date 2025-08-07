variable "ami_id" {
  description = "AMI ID for Bastion host"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Bastion host"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name to access Bastion"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where Bastion will be deployed"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to access Bastion via SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "bastion_role_name" {
  description = "IAM role name to attach to the Bastion instance"
  type        = string
}
