terraform {
  required_version = ">= 1.15.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.45.0"
    }
  }

  backend "s3" {
    bucket = "sctp-ce12-tfstate-bucket"
    key    = "sk-module3_5.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = "ap-southeast-1"
}
