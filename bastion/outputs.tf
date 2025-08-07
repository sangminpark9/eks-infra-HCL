output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Bastion 호스트 공인 IP 주소"
}
output "bastion_security_group_id" {
  value       = aws_security_group.bastion_sg.id
  description = "Bastion 호스트 보안 그룹 ID"
}
