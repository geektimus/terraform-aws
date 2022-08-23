terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
    }
  }
}

provider "aws" {
    region = "us-east-1"
    access_key = ""
    secret_key = ""
}

# Create VPC
resource "aws_vpc" "alfheim-vpc" {
    cidr_block = "10.0.0.0/16"
}