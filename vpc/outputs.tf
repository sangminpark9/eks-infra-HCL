# VPC와 서브넷 ID들을 출력
output "vpc_id"              { value = aws_vpc.main.id }
output "public_subnet_ids"   { value = aws_subnet.public[*].id }
output "private_subnet_ids"  { value = aws_subnet.outposts[*].id }
output "outposts_subnet_ids" { value = aws_subnet.outposts[*].id }  # 추가된 출력
