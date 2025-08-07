# IAM Module

## 개요
이 모듈은 EKS 클러스터, 워커 노드, 베스천 호스트에 필요한 IAM 역할과 정책을 생성합니다. AWS 관리형 정책을 활용하여 최소 권한 원칙을 적용합니다.

## 왜 이렇게 설계했는가?

### 1. 역할별 분리된 IAM 역할
```hcl
resource "aws_iam_role" "eks_cluster" { ... }
resource "aws_iam_role" "eks_worker" { ... }
resource "aws_iam_role" "bastion" { ... }
```

**이유**:
- **책임 분리**: 각 컴포넌트별로 필요한 최소한의 권한만 부여
- **보안 강화**: 하나의 역할이 손상되어도 다른 서비스에 영향 최소화
- **관리 용이성**: 역할별 권한 변경 시 영향 범위를 명확히 파악 가능

### 2. AWS 관리형 정책 사용
```hcl
resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```

**이유**:
- **AWS 베스트 프랙티스**: AWS에서 권장하는 최소 권한 정책 세트
- **자동 업데이트**: AWS가 서비스 변경사항에 따라 정책을 자동 업데이트
- **보안**: 직접 작성한 정책보다 보안 검증이 완료된 정책
- **유지보수**: 커스텀 정책 작성 및 관리 부담 최소화

### 3. 서비스별 AssumeRole 정책
```hcl
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
```

**이유**:
- **서비스 제한**: 해당 AWS 서비스만 역할을 assume 가능하도록 제한
- **보안**: 사용자나 다른 서비스의 무단 역할 사용 방지
- **AWS 표준**: AWS 서비스 통합의 표준 방식

### 4. EKS 워커 노드 다중 정책 부착
```hcl
resource "aws_iam_role_policy_attachment" "eks_worker_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cni_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
```

**이유**:
- **워커 노드 기능**: EKS 클러스터 참여, 포드 네트워킹 관리 권한 필요
- **CNI 플러그인**: AWS VPC CNI가 포드에 VPC IP 할당을 위한 권한 필요
- **컨테이너 레지스트리**: ECR에서 컨테이너 이미지 풀링 권한

### 5. 베스천 호스트 SSM 권한
```hcl
resource "aws_iam_role_policy_attachment" "bastion_attach" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**이유**:
- **세션 관리**: SSH 키 없이도 AWS SSM Session Manager로 접근 가능
- **보안 향상**: SSH 포트를 열지 않고도 안전한 셸 접근
- **감사 추적**: 모든 세션이 CloudTrail에 로깅되어 추적 가능
- **확장성**: 추후 패치 관리, 로그 수집 등 SSM 기능 활용 가능

### 6. 데이터 소스를 통한 정책 문서 생성
```hcl
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    # ...
  }
}
```

**이유**:
- **가독성**: JSON 문자열보다 HCL 구문이 더 읽기 쉽고 관리하기 용이
- **검증**: Terraform이 정책 문서 구문을 검증
- **재사용**: 같은 정책 문서를 여러 곳에서 참조 가능

### 7. 출력값 제공
```hcl
output "eks_cluster_role_arn"  { value = aws_iam_role.eks_cluster.arn }
output "bastion_role_name"     { value = aws_iam_role.bastion.name }
```

**이유**:
- **모듈 간 연결**: 다른 모듈에서 역할을 참조할 때 필요
- **ARN vs Name**: EKS는 ARN 필요, 인스턴스 프로파일은 이름 필요
- **일관성**: 모든 생성된 역할의 정보를 표준화된 방식으로 노출

## 보안 고려사항

### 최소 권한 원칙
- 각 역할은 해당 기능 수행에 필요한 최소한의 권한만 보유
- AWS 관리형 정책을 사용하여 과도한 권한 부여 방지

### 역할 분리
- EKS 컨트롤 플레인과 워커 노드의 역할을 명확히 분리
- 베스천 호스트는 관리 전용 역할로 제한

### 추적성
- 모든 역할 사용이 CloudTrail에 기록됨
- SSM Session Manager 사용 시 세션 활동 로깅

## 프로덕션 고려사항

1. **역할 세분화**: 팀별, 환경별로 더 세분화된 역할 구성
2. **권한 경계**: IAM 권한 경계를 사용하여 최대 권한 제한
3. **태그 기반 액세스**: 리소스 태그 기반 세밀한 액세스 제어
4. **교차 계정 액세스**: 멀티 계정 환경에서의 역할 신뢰 관계 설정