# Terraform EKS Infrastructure

이 Terraform 프로젝트는 AWS EKS(Elastic Kubernetes Service) 클러스터와 필수 지원 인프라를 구축합니다.

## 아키텍처 개요

이 프로젝트는 다음 구성 요소를 배포합니다:

- **VPC**: 다중 가용영역에 걸친 퍼블릭/프라이빗 서브넷이 있는 사용자 정의 VPC
- **EKS 클러스터**: 관리형 Kubernetes 컨트롤 플레인 및 워커 노드 그룹
- **IAM**: EKS 클러스터, 워커 노드, 베스천 호스트용 역할 및 정책
- **베스천 호스트**: 안전한 SSH 접근을 위한 퍼블릭 서브넷의 EC2 인스턴스
- **보안**: 네트워크 보안 그룹 구성

## 프로젝트 구조

```
.
├── README.md                # 이 파일
├── main.tf                  # 메인 Terraform 구성 (모듈 호출)
├── provider.tf              # AWS 프로바이더 설정
├── variables.tf             # 전역 변수 정의
├── terraform.tfvars         # 변수 값 설정
├── versions.tf              # Terraform 및 프로바이더 버전 제약
├── outputs.tf               # 출력 값 정의
├── bastion/                 # 베스천 호스트 모듈
│   ├── README.md
│   ├── bastion.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── eks/                     # EKS 클러스터 모듈
│   ├── README.md
│   ├── eks.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── iam/                     # IAM 역할 및 정책 모듈
│   ├── README.md
│   ├── iam.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
└── vpc/                     # VPC 네트워킹 모듈
    ├── README.md
    ├── vpc.tf
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf
```

## 빠른 시작

### 사전 요구사항

1. **AWS CLI** - 적절한 권한을 가진 AWS 자격 증명으로 구성
2. **Terraform** >= 1.3.0
3. **kubectl** - 배포 후 클러스터 관리용 (선택사항)

### 배포 단계

1. **프로젝트 준비**
   ```bash
   git clone <repository-url>
   cd terraform-eks
   ```

2. **변수 설정**
   
   `terraform.tfvars` 파일을 편집하여 필수 변수를 설정:
   ```hcl
   bastion_ami = "ami-0abcdef1234567890"  # 사용할 AMI ID로 변경
   key_name    = "my-ssh-key"             # 기존 SSH 키 페어 이름으로 변경
   ssh_cidr    = "0.0.0.0/0"             # 필요에 따라 제한된 CIDR로 변경
   ```

3. **Terraform 초기화**
   ```bash
   terraform init
   ```

4. **배포 계획 확인**
   ```bash
   terraform plan
   ```

5. **인프라 배포**
   ```bash
   terraform apply
   ```

### 배포 후 설정

1. **kubectl 구성**
   ```bash
   aws eks update-kubeconfig --region ap-northeast-2 --name my-cluster
   ```

2. **클러스터 상태 확인**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. **베스천 호스트 접속** (필요시)
   ```bash
   ssh -i ~/.ssh/your-key.pem ec2-user@<bastion-public-ip>
   ```

## 주요 구성 요소 설명

### VPC 모듈
- 10.0.0.0/16 CIDR 블록 사용
- 2개 가용영역에 퍼블릭/프라이빗 서브넷 쌍 생성
- NAT Gateway를 통한 프라이빗 서브넷 인터넷 연결

### EKS 모듈
- Kubernetes 1.28 버전 사용
- 프라이빗 서브넷에 워커 노드 배포
- t3.medium 인스턴스 타입으로 1-3개 노드 자동 확장

### IAM 모듈
- EKS 클러스터용 서비스 역할
- 워커 노드용 인스턴스 역할 (CNI, 노드 정책 포함)
- 베스천 호스트용 역할 (SSM 관리 포함)

### 베스천 호스트 모듈
- 퍼블릭 서브넷에 t3.micro 인스턴스 배포
- SSH 접근을 위한 보안 그룹 구성
- 프라이빗 리소스 접근을 위한 점프 박스 역할

## 보안 고려사항

- **네트워크 격리**: 워커 노드는 프라이빗 서브넷에 배치
- **접근 제어**: 베스천 호스트를 통한 제한된 SSH 접근
- **IAM**: 최소 권한 원칙에 따른 역할 분리
- **보안 그룹**: 필요한 포트만 허용하는 제한적 규칙

## 비용 최적화 팁

- 개발 환경에서는 노드 수를 1개로 축소 고려
- 사용하지 않을 때는 `terraform destroy`로 리소스 정리
- NAT Gateway 대신 NAT Instance 사용 고려 (비용 절감)
- 스팟 인스턴스 사용 검토 (프로덕션 외 환경)

## 문제 해결

### 일반적인 오류

1. **IAM 권한 부족**
   - AWS CLI 사용자에게 EKS, EC2, IAM, VPC 권한 확인
   
2. **SSH 키 페어 없음**
   - AWS 콘솔에서 키 페어 생성 후 `terraform.tfvars`에 이름 설정

3. **AMI ID 오류**
   - 해당 리전에서 사용 가능한 AMI ID로 업데이트

4. **리전별 가용성**
   - 일부 인스턴스 타입이 모든 AZ에서 사용 불가할 수 있음

### 로그 확인
```bash
# Terraform 상세 로그
TF_LOG=DEBUG terraform apply

# AWS CLI로 리소스 상태 확인
aws eks describe-cluster --name my-cluster --region ap-northeast-2
```

## 정리

인프라를 완전히 제거하려면:
```bash
terraform destroy
```

**⚠️ 경고**: 이 명령은 모든 리소스를 영구적으로 삭제합니다.

## 기여하기

1. 이 저장소를 포크
2. 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 생성

## 지원 및 문의

- 이슈 등록: GitHub Issues 탭 사용
- 문서: 각 모듈의 README.md 참조