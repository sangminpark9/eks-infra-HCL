# Bastion Module

## 개요
이 모듈은 프라이빗 서브넷의 EKS 클러스터와 다른 리소스에 안전하게 접근하기 위한 베스천 호스트(점프 박스)를 생성합니다. SSH와 AWS SSM Session Manager를 통한 접근을 지원합니다.

## 왜 이렇게 설계했는가?

### 1. 퍼블릭 서브넷 배치
```hcl
resource "aws_instance" "bastion" {
  subnet_id = element(var.public_subnet_ids, 0)  # 첫 번째 퍼블릭 서브넷
  associate_public_ip_address = true
}
```

**이유**:
- **외부 접근성**: 인터넷에서 직접 SSH 접근이 가능해야 함
- **점프 박스 역할**: 프라이빗 리소스로의 안전한 진입점 제공
- **관리 편의성**: 고정된 퍼블릭 IP로 일관된 접근점 확보
- **비용 효율성**: 단일 AZ 사용으로 불필요한 중복 비용 방지

### 2. 전용 보안 그룹 생성
```hcl
resource "aws_security_group" "bastion_sg" {
  name = "bastion-sg"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }
}
```

**이유**:
- **최소 권한**: SSH(22번 포트)만 허용하여 공격 표면 최소화
- **접근 제어**: 특정 CIDR 블록에서만 접근 허용 (설정 가능)
- **격리**: 베스천 전용 보안 그룹으로 다른 리소스와 분리
- **감사**: 명확한 네트워크 접근 정책으로 보안 감사 용이

### 3. 전체 아웃바운드 허용
```hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**이유**:
- **프록시 기능**: 프라이빗 리소스에 대한 모든 종류의 접근 중계
- **패키지 관리**: yum/apt 등을 통한 패키지 설치 및 업데이트
- **운영 도구**: kubectl, aws-cli 등 관리 도구의 외부 API 호출
- **유연성**: 다양한 포트와 프로토콜을 통한 관리 작업 지원

### 4. IAM 인스턴스 프로파일 연결
```hcl
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = var.bastion_role_name
}

resource "aws_instance" "bastion" {
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name
}
```

**이유**:
- **SSM 지원**: Session Manager를 통한 브라우저 기반 셸 접근
- **AWS CLI**: 베스천에서 AWS 리소스를 직접 관리 가능
- **보안**: SSH 키 없이도 안전한 접근 방법 제공
- **감사**: 모든 세션 활동이 CloudTrail에 기록됨

### 5. 단일 인스턴스 구성
```hcl
resource "aws_instance" "bastion" {
  # count나 for_each 없이 단일 인스턴스
  instance_type = var.instance_type  # 기본값: t3.micro
}
```

**이유**:
- **비용 최적화**: 관리 목적으로만 사용되므로 최소 사양으로 충분
- **단순성**: 고가용성보다는 단순한 구조로 관리 부담 최소화
- **사용 패턴**: 베스천 호스트는 상시 사용되지 않으므로 중복 불필요
- **복구**: 장애 시 terraform apply로 빠르게 재생성 가능

### 6. 외부 변수 의존성
```hcl
variable "bastion_role_name" {
  description = "IAM role name to attach to the Bastion instance"
  type        = string
}
```

**이유**:
- **모듈 분리**: IAM 관리를 별도 모듈에 위임하여 책임 분산
- **재사용성**: 동일한 IAM 역할을 다른 베스천 인스턴스에서도 사용 가능
- **보안 관리**: IAM 정책 변경이 필요할 때 IAM 모듈만 수정하면 됨

### 7. SSH 키 관리 방식
```hcl
resource "aws_instance" "bastion" {
  key_name = var.key_name  # 외부에서 전달받음
}
```

**이유**:
- **기존 키 활용**: 새로운 SSH 키를 생성하지 않고 기존 키 페어 사용
- **보안**: 키 생성을 Terraform 외부에서 관리하여 상태 파일에 프라이빗 키 저장 방지
- **유연성**: 팀에서 사용하는 표준 SSH 키를 활용 가능
- **접근 관리**: SSH 키 배포 정책을 조직의 기존 프로세스와 통합

### 8. AMI ID를 변수로 받는 이유
```hcl
variable "ami_id" {
  description = "AMI ID for Bastion host"
  type        = string
}
```

**이유**:
- **리전 호환성**: AMI ID는 리전별로 다르므로 하드코딩 불가
- **보안 업데이트**: 최신 보안 패치가 적용된 AMI 선택 가능
- **표준화**: 조직의 표준 AMI 사용 강제
- **유연성**: CentOS, Ubuntu 등 원하는 OS 선택 가능

### 9. 출력값 설계
```hcl
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "bastion_security_group_id" {
  value = aws_security_group.bastion_sg.id
}
```

**이유**:
- **접근 정보**: SSH 접근을 위한 퍼블릭 IP 주소 제공
- **보안 그룹 연동**: 다른 리소스에서 베스천으로부터의 접근 허용 시 사용
- **자동화**: CI/CD 파이프라인에서 베스천 IP를 자동으로 활용 가능

## 보안 고려사항

### 네트워크 보안
- **CIDR 제한**: SSH 접근을 특정 IP 대역으로만 제한 권장
- **포트 제한**: SSH 22번 포트만 허용하여 공격 표면 최소화
- **아웃바운드 모니터링**: 필요 시 아웃바운드 트래픽도 제한 고려

### 접근 관리
- **이중 인증**: SSH 키 + SSM Session Manager 이중 접근 방법
- **키 순환**: 정기적인 SSH 키 교체 정책 수립
- **로그 모니터링**: CloudTrail, VPC Flow Logs 활용한 접근 모니터링

### 인스턴스 보안
- **최신 패치**: 정기적인 OS 및 패키지 업데이트
- **최소 소프트웨어**: 필요한 도구만 설치하여 공격 표면 최소화
- **방화벽**: 인스턴스 레벨 방화벽(iptables) 추가 설정

## 운영 고려사항

### 접근 방법

1. **SSH 접근**
   ```bash
   ssh -i ~/.ssh/your-key.pem ec2-user@<bastion-public-ip>
   ```

2. **SSM Session Manager**
   - AWS 콘솔에서 "Connect" 버튼 클릭
   - AWS CLI: `aws ssm start-session --target <instance-id>`

### 주요 사용 사례

1. **EKS 클러스터 관리**
   ```bash
   # 베스천 호스트에서 실행
   aws eks update-kubeconfig --name my-cluster --region ap-northeast-2
   kubectl get nodes
   ```

2. **데이터베이스 접근**
   ```bash
   # 프라이빗 RDS 인스턴스 접근
   mysql -h private-rds-endpoint -u username -p
   ```

3. **SSH 터널링**
   ```bash
   # 로컬에서 베스천을 통한 터널링
   ssh -L 8080:private-service:80 -i key.pem ec2-user@bastion-ip
   ```

## 프로덕션 개선사항

### 고가용성
```hcl
# 다중 AZ 베스천 호스트
resource "aws_instance" "bastion" {
  count             = length(var.public_subnet_ids)
  subnet_id         = var.public_subnet_ids[count.index]
  availability_zone = data.aws_subnet.public[count.index].availability_zone
}
```

### 자동화 향상
```hcl
# 사용자 데이터로 초기 설정 자동화
user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install -y kubectl
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
EOF
```

### 모니터링 강화
```hcl
# CloudWatch 에이전트 설치
# 상세 시스템 메트릭 수집
# 로그 중앙화
```