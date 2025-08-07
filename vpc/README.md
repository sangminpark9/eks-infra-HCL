# VPC Module

## 개요
이 모듈은 AWS VPC와 관련 네트워킹 리소스를 생성합니다. EKS 클러스터와 베스천 호스트를 지원하기 위한 퍼블릭/프라이빗 서브넷 구조를 제공합니다.

## 왜 이렇게 설계했는가?

### 1. 듀얼 서브넷 구조 (퍼블릭 + 프라이빗)
```hcl
resource "aws_subnet" "public" { ... }
resource "aws_subnet" "private" { ... }
```

**이유**: 
- **보안 격리**: EKS 워커 노드는 프라이빗 서브넷에 배치하여 직접 인터넷 접근 차단
- **접근성**: 베스천 호스트와 NAT Gateway는 퍼블릭 서브넷에 배치하여 관리 접근점 제공
- **베스트 프랙티스**: AWS Well-Architected Framework의 보안 원칙을 따름

### 2. 다중 가용영역 (Multi-AZ) 배포
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

count = 2  # 첫 번째와 두 번째 AZ 사용
```

**이유**:
- **고가용성**: 단일 AZ 장애 시에도 서비스 연속성 보장
- **EKS 요구사항**: EKS는 최소 2개 AZ의 서브넷 필요
- **로드 분산**: 워커 노드를 여러 AZ에 분산 배치 가능

### 3. NAT Gateway 사용
```hcl
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
}
```

**이유**:
- **아웃바운드 연결**: 프라이빗 서브넷의 EKS 노드가 컨테이너 이미지 다운로드, API 호출 등을 위해 인터넷 접근 필요
- **보안**: 인바운드 연결은 차단하면서 아웃바운드만 허용
- **관리형 서비스**: AWS에서 관리하여 운영 부담 최소화

### 4. 단일 NAT Gateway 구성
```hcl
# 첫 번째 퍼블릭 서브넷에만 NAT Gateway 생성
subnet_id = aws_subnet.public[0].id
```

**이유**:
- **비용 최적화**: NAT Gateway는 시간당 과금되므로 개발/테스트 환경에서는 단일 사용
- **트레이드오프**: 고가용성보다 비용을 우선시 (프로덕션에서는 AZ별 NAT Gateway 권장)

### 5. 표준 CIDR 블록 사용
```hcl
variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

# 퍼블릭: 10.0.1.0/24, 10.0.2.0/24
# 프라이빗: 10.0.101.0/24, 10.0.102.0/24
```

**이유**:
- **RFC1918 준수**: 프라이빗 네트워크 주소 범위 사용
- **충분한 주소 공간**: /16은 65,536개 IP 제공으로 대부분 사용 사례에 충분
- **서브넷 분리**: 퍼블릭(1-50)과 프라이빗(101-150) 대역을 명확히 구분

### 6. 인터넷 게이트웨이 자동 연결
```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
```

**이유**:
- **퍼블릭 접근**: 베스천 호스트와 NAT Gateway의 인터넷 연결 필수
- **자동화**: 수동 설정 실수 방지 및 배포 자동화

## 주요 출력값

- `vpc_id`: 다른 모듈에서 VPC 참조용
- `public_subnet_ids`: 베스천 호스트 배치용
- `private_subnet_ids`: EKS 워커 노드 배치용

## 사용 예시

```hcl
module "vpc" {
  source = "./vpc"
  vpc_cidr_block = "10.0.0.0/16"  # 선택사항
}
```

## 프로덕션 고려사항

1. **다중 NAT Gateway**: 각 AZ마다 NAT Gateway 배치하여 고가용성 확보
2. **VPC 엔드포인트**: S3, ECR 등에 대한 VPC 엔드포인트 추가하여 비용 절감
3. **네트워크 ACL**: 추가 네트워크 레이어 보안 설정
4. **플로우 로그**: VPC 트래픽 모니터링 및 분석용

