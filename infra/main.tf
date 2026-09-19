terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fedora Cloud Base AMI (official Fedora Project account: 125523088429)
data "aws_ami" "fedora" {
  most_recent = true
  owners      = ["125523088429"]

  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-*.x86_64*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "app" {
  name        = "shortener-sg"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "shortener-sg"
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y podman
    mkdir -p /opt/shortener/pgdata /opt/shortener/logs
  EOF

  tags = {
    Name = "shortener-vm"
  }
}
