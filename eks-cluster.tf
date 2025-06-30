# EKS 클러스터 생성
# 쿠버네티스 컨트롤 플레인을 관리하는 메인 클러스터 리소스
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn  # 클러스터 관리를 위한 IAM 역할
  version  = "1.28"                    # 쿠버네티스 버전

  # VPC 및 네트워킹 구성
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)  # 퍼블릭/프라이빗 서브넷 모두 사용
    endpoint_private_access = true   # 프라이빗 서브넷에서 API 서버 접근 허용
    endpoint_public_access  = true   # 인터넷을 통한 API 서버 접근 허용
    security_group_ids      = [aws_security_group.cluster.id]  # 클러스터용 보안 그룹
  }

  # 클러스터 로깅 활성화 - 모니터링 및 디버깅을 위해 모든 로그 타입 수집
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # IAM 정책 연결이 완료된 후 클러스터 생성하도록 의존성 설정
  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]

  tags = {
    Name = var.cluster_name
  }
}

# EKS 노드 그룹 생성
# 실제 워크로드를 실행할 EC2 인스턴스들의 집합
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main-nodes"
  node_role_arn   = aws_iam_role.node_group.arn  # 노드 그룹용 IAM 역할
  subnet_ids      = aws_subnet.private[*].id     # 프라이빗 서브넷에만 워커 노드 배치

  # 노드 그룹 스케일링 설정
  scaling_config {
    desired_size = 3  # 원하는 노드 수
    max_size     = 3  # 최대 노드 수
    min_size     = 3  # 최소 노드 수
  }

  instance_types = [var.node_instance_type]  # EC2 인스턴스 타입
  capacity_type  = "ON_DEMAND"               # 온디맨드 인스턴스 사용

  # 노드 업데이트 시 동시에 사용 불가능한 노드 수 제한
  update_config {
    max_unavailable = 1
  }

  # SSH 원격 접속 설정
  remote_access {
    ec2_ssh_key = aws_key_pair.node_key.key_name                    # SSH 키 페어
    source_security_group_ids = [aws_security_group.node_group.id]  # SSH 접속 허용할 보안 그룹
  }

  disk_size = 20  # 노드당 EBS 볼륨 크기 (GB)

  # 노드에 적용할 쿠버네티스 레이블
  labels = {
    role        = "worker"
    environment = "production"
  }

  # 노드 인스턴스에 적용할 AWS 태그
  tags = {
    Name                                        = "${var.cluster_name}-worker-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"  # 클러스터 소유권 표시
  }

  # 모든 IAM 정책이 연결된 후 노드 그룹 생성하도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# EKS 클러스터의 OIDC issuer에서 TLS 인증서 정보 조회
# IRSA(IAM Roles for Service Accounts) 설정을 위해 필요
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# AWS IAM OIDC Identity Provider 생성
# 쿠버네티스 서비스 어카운트가 AWS IAM 역할을 assume할 수 있게 해주는 브릿지
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]                                           # AWS STS를 클라이언트로 등록
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint] # OIDC provider 신뢰성 검증용 인증서 지문
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer                 # EKS 클러스터의 OIDC issuer URL

  tags = {
    Name = "${var.cluster_name}-irsa"
  }
}

# Cluster Autoscaler용 IAM 역할 생성
# IRSA를 통해 cluster-autoscaler 서비스 어카운트가 사용할 역할
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity",  # OIDC를 통한 역할 assume
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn  # 위에서 생성한 OIDC provider
      },
      Condition = {
        StringEquals = {
          # 특정 서비스 어카운트만 이 역할을 assume할 수 있도록 제한
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler",
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Cluster Autoscaler가 Auto Scaling Group을 제어하기 위한 IAM 정책 생성
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-cluster-autoscaler"
  description = "EKS cluster-autoscaler policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "autoscaling:DescribeAutoScalingGroups",        # ASG 정보 조회
        "autoscaling:DescribeAutoScalingInstances",     # ASG 인스턴스 정보 조회
        "autoscaling:DescribeLaunchConfigurations",     # 런치 설정 조회
        "autoscaling:DescribeTags",                     # ASG 태그 조회
        "autoscaling:SetDesiredCapacity",               # 원하는 용량 설정 (스케일 업/다운)
        "autoscaling:TerminateInstanceInAutoScalingGroup", # 인스턴스 종료
        "ec2:DescribeLaunchTemplateVersions"            # 런치 템플릿 버전 조회
      ],
      Resource = "*"
    }]
  })
}

# Cluster Autoscaler 역할에 정책 연결
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}