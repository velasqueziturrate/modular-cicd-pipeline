resource "aws_security_group" "ansible_target" {
  name        = "ansible-target-sg"
  description = "Allow SSH for Ansible configuration"

  ingress {
    from_port   = 22
    to_port     = 22
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "ansible_target" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "modular-cicd-ansible"
  vpc_security_group_ids = [aws_security_group.ansible_target.id]

  tags = {
    Name = "ansible-target"
  }
}

output "instance_public_ip" {
  value = aws_instance.ansible_target.public_ip
}
