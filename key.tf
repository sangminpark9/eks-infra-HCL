resource "aws_key_pair" "node_key" {
  key_name   = "${var.cluster_name}-node-key"
  public_key = file("~/.ssh/id_rsa.pub")  # 본인의 SSH 공개 키 경로
}
