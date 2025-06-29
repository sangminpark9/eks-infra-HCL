좋습니다! 아래는 해당 Terraform EKS 인프라 구성 프로젝트에 적합한 `README.md` 예시입니다:

---

````markdown
# terraform-eks-infra

Terraform을 사용해 AWS에 EKS 클러스터(3노드 구성)를 자동으로 배포하는 인프라 프로젝트입니다.

## 📁 프로젝트 구성

```bash
.
├── provider.tf              # Terraform 및 AWS Provider 설정
├── variables.tf             # 사용자 정의 변수 정의
├── vpc.tf                   # VPC, Subnet, NAT, IGW, Routing 설정
├── security.tf              # EKS 클러스터 및 노드 그룹 보안 그룹 설정
├── eks-cluster.tf           # EKS 클러스터와 노드 그룹 자원 정의
├── iam.tf                   # EKS와 AutoScaler에 필요한 IAM 역할 및 정책
├── key.tf                   # 노드 접근을 위한 SSH Key 등록
├── outputs.tf               # Terraform apply 후 출력되는 정보 정의
└── locals.tf (optional)     # 로컬 변수 정의 (선택)
````

## 📌 주요 기능

* ✅ 퍼블릭/프라이빗 서브넷을 포함한 VPC 구성
* ✅ EKS 클러스터 + 3개 노드 고정 구성
* ✅ 클러스터 Auto Scaling을 위한 IAM + OIDC 연동
* ✅ SSH Key를 통한 노드 접속 지원
* ✅ `kubectl` 자동 구성 명령 출력

## 🔧 사용 방법

### 1. 의존성 설치

* Terraform ≥ 1.0
* AWS CLI
* kubectl

### 2. 환경 변수 또는 Terraform 변수 지정

`variables.tf` 또는 CLI에서 변수 정의

```bash
# 예시: default AWS profile 사용
export AWS_PROFILE=default
```

### 3. terraform 실행

```bash
terraform init
terraform plan
terraform apply
```

### 4. 클러스터 접근 설정

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name my-eks-cluster
```

### 5. 접속 확인

```bash
kubectl get nodes
```

## 🔐 참고

* `key.tf`에서 사용하는 SSH 공개키는 반드시 `~/.ssh/id_rsa.pub` 경로에 존재해야 합니다. 필요 시 경로 수정.
* 프라이빗 서브넷에 노드가 배포되므로, 접근은 NAT Gateway 및 SSH를 통한 Bastion 사용이 필요할 수 있습니다.
