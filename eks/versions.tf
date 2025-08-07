terraform {
  required_version = ">=1.3.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"  # 명시적으로 안정된 버전 지정
    }
  }
}
