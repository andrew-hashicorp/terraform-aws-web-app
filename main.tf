# Random password for the database — Terraform generates this, never hardcoded
resource "random_password" "db" {
  length  = 16
  special = false
}

# Security group for EC2 — allows HTTP traffic from the internet
resource "aws_security_group" "app" {
  name        = "${var.app_name}-app"
  description = "Allow HTTP traffic to the app"

  ingress {
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
}

# Security group for RDS — only allows traffic from the EC2 security group
resource "aws_security_group" "db" {
  name        = "${var.app_name}-db"
  description = "Allow Postgres traffic from app only"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "main" {
  identifier          = var.app_name
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  db_name             = var.db_name
  username            = "appuser"
  password            = random_password.db.result
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = var.app_name
  }
}

 # Find the latest Amazon Linux 2023 AMI — this is the OS for the EC2 instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# EC2 instance — installs Docker and runs your container on startup
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    docker run -d \
      -p 80:3000 \
      -e DATABASE_URL="postgresql://appuser:${random_password.db.result}@${aws_db_instance.main.endpoint}/${var.db_name}" \
      -e PORT=3000 \
      --restart always \
      ${var.docker_image}
  EOF
  tags = {
    Name = var.app_name
  }
}
