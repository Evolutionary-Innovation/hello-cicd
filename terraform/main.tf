resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  key_name = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y nodejs git

    npm install -g pm2
  EOF

  tags = {
    managed-by = "terraform"
    name = "hello-cicd"
  }
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

resource "aws_key_pair" "deployer" {
  key_name   = "hello-cicd"
  public_key = file("${path.module}/../keys/public/hello-cicd.pub")

  lifecycle {
    ignore_changes = [public_key]
  }
}
