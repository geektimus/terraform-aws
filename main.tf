terraform {
  required_version = ">=1.2.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "codingmaniacs-tf"
    key            = "codingmaniacs-deployments"
    region         = "us-east-1"
    dynamodb_table = "codingmaniacs-tf-lock"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Default VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

# Create VPC
resource "aws_vpc" "production_vpc_0" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name : "production"
  }
}

resource "aws_internet_gateway" "production_gw" {
  vpc_id = aws_vpc.production_vpc_0.id

  tags = {
    Name = "production"
  }
}

resource "aws_route_table" "prod_route_table_0" {
  vpc_id = aws_vpc.production_vpc_0.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.production_gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.production_gw.id
  }

  tags = {
    Name = "production"
  }
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  type        = string
}

resource "aws_subnet" "production_subnet_0" {
  vpc_id            = aws_vpc.production_vpc_0.id
  cidr_block        = var.subnet_prefix
  availability_zone = "us-east-1a"
  tags = {
    Name : "production"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.production_subnet_0.id
  route_table_id = aws_route_table.prod_route_table_0.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.production_vpc_0.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodeJs from VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.production_subnet_0.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"

  depends_on = [
    aws_internet_gateway.production_gw
  ]
}

output "pihole_public_ip" {
  value = aws_eip.one.public_ip
}

resource "aws_instance" "pihole" {
  ami               = "ami-052efd3df9dad4825"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "valhala_keypair"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  tags = {
    Name = "valhala_web"
  }

  user_data = <<-EOF
              #!/bin/env bash
              sudo apt update -y
              sudo apt upgrade -y
              sudo apt install unzip unbound -y
              EOF
}

locals {
  buckets = {
    first_bucket  = "thumbnail_bucket_sandbox_01"
    second_bucket = "thumbnail_bucket_sandbox_02"
  }
}

resource "aws_s3_bucket" "thumbnails" {
  for_each = local.buckets
  bucket   = each.value
}

resource "aws_s3_bucket" "terraform-backend" {
  bucket = "codingmaniacs-tf"
}
