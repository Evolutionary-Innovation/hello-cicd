resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  key_name = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash

    exec > >(tee /var/log/user-data.log)
    exec 2>&1

    set -e

    dnf update -y

    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ec2-user

    mkdir -p /home/ec2-user/app

    chown -R ec2-user:ec2-user /home/ec2-user/app

    echo "Bootstrap complete" >/tmp/bootstrap-success.txt

  EOF
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  name = "hello-cicd-web"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "hello-cicd-eip"
  }
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "hello-cicd"
  public_key = file("${path.module}/../keys/public/hello-cicd.pub")

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_ecr_repository" "hello_cicd" {
  name                 = "hello-cicd"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
