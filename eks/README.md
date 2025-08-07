# EKS Module

## 개요
이 모듈은 AWS EKS(Elastic Kubernetes Service) 클러스터와 관리형 노드 그룹을 생성합니다. 프로덕션 환경에서 사용할 수 있는 확장 가능하고 안전한 Kubernetes 클러스터를 제공합니다.

## 왜 이렇게 설계했는가?

### 1. 관리형 EKS 클러스터 사용
```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  # ...
}
```

**이유**:
- **운영 부담 최소화**: AWS가 컨트롤 플레인(API 서버, etcd, 스케줄러 등)을 완전 관리
- **고가용성**: 다중 AZ에 걸쳐 자동으로 컨트롤 플레인 복제 및 장애 복구
- **보안 업데이트**: AWS가 자동으로 보안 패치 적용
- **확장성**: 트래픽 증가에 따라 컨트롤 플레인 자동 확장

### 2. 외부 IAM 역할 참조
```hcl
role_arn = var.cluster_role_arn  # IAM 모듈에서 전달
```

**이유**:
- **모듈 분리**: IAM 관리와 EKS 관리를 별도 모듈로 분리하여 책임 분산
- **재사용성**: 동일한 IAM 역할을 여러 클러스터에서 재사용 가능
- **의존성 명확화**: 모듈 간 의존성을 명시적으로 표현

### 3. VPC 서브넷 설정
```hcl
vpc_config {
  subnet_ids = var.subnet_ids  # 프라이빗 서브넷 사용
}
```

**이유**:
- **보안**: EKS API 서버를 프라이빗 서브넷에 배치하여 직접 인터넷 노출 차단
- **네트워크 격리**: VPC 내부에서만 클러스터 API에 접근 가능
- **유연성**: 퍼블릭/프라이빗 엔드포인트 접근을 나중에 설정 가능

### 4. 관리형 노드 그룹 사용
```hcl
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  # ...
}
```

**이유**:
- **자동 관리**: AWS가 노드의 업데이트, 패치, 교체를 자동 처리
- **원활한 배포**: 롤링 업데이트로 서비스 중단 없이 노드 업데이트
- **AMI 관리**: 최적화된 Amazon Linux AMI 자동 사용 및 업데이트
- **Auto Scaling**: ASG 기반 자동 확장/축소

### 5. 스케일링 구성
```hcl
scaling_config {
  desired_size = 2
  max_size     = 3
  min_size     = 1
}
```

**이유**:
- **비용 효율성**: 최소 1개 노드로 시작하여 비용 최적화
- **가용성**: desired_size 2로 기본 고가용성 확보
- **확장성**: 최대 3개까지 자동 확장으로 트래픽 급증 대응
- **개발 친화적**: 소규모 팀의 개발/테스트 환경에 적합

### 6. 하드코딩된 스케일링 값
```hcl
scaling_config {
  desired_size = 2  # 변수 대신 하드코딩
  max_size     = 3
  min_size     = 1
}
```

**이유**:
- **단순성**: 이 데모 환경에서는 고정된 값으로 충분
- **예측 가능성**: 배포 시 항상 동일한 구성으로 생성됨
- **비용 제어**: 의도하지 않은 대규모 확장 방지

### 7. 노드 그룹 의존성 설정
```hcl
resource "aws_eks_node_group" "workers" {
  cluster_name = aws_eks_cluster.main.name  # 클러스터 생성 후 노드 그룹 생성
}
```

**이유**:
- **순서 보장**: Terraform이 클러스터를 먼저 생성한 후 노드 그룹 생성
- **안정성**: 클러스터가 완전히 준비된 후 워커 노드 조인
- **오류 방지**: 클러스터 없이 노드 그룹 생성 시도 방지

### 8. 출력값으로 보안 그룹 ID 제공
```hcl
output "eks_cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
```

**이유**:
- **자동 생성**: EKS가 자동으로 생성하는 보안 그룹 정보 노출
- **추가 구성**: 다른 모듈에서 이 보안 그룹을 참조하여 추가 규칙 설정 가능
- **통합**: 베스천 호스트나 다른 리소스에서 EKS 클러스터 접근 설정 시 필요

### 9. 인스턴스 타입을 변수로 받지만 사용하지 않음
```hcl
# variables.tf에 정의되어 있지만 실제 리소스에서 미사용
variable "node_instance_type" { ... }

resource "aws_eks_node_group" "workers" {
  # instance_types 미지정 시 기본값 사용
}
```

**이유**:
- **AWS 기본값 활용**: 관리형 노드 그룹의 기본 인스턴스 타입 사용
- **단순화**: 현재 구현에서는